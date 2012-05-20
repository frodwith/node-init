fs     = require 'fs'
daemon = require 'daemon'

exports.printStatus = (st) ->
    if st.pid
        console.log 'Process running with pid %d.', st.pid
        process.exit 0

    else if st.exists
        console.log 'Pidfile exists, but process is dead.'
        process.exit 1
    else
        console.log 'Not running.'
        process.exit 3

exports.status = (pidfile, cb = exports.printStatus) ->
    fs.readFile pidfile, 'utf8', (err, data) ->
        if err
            cb exists: err.code isnt 'ENOENT'
        else if match = /^\d+/.exec(data)
            pid = parseInt match[0]
            try
                process.kill pid, 0
                cb pid: pid
            catch e
                cb exists: true
        else
            cb exists: true

exports.startSucceeded = (pid) ->
    if pid
        console.log 'Process already running with pid %d.', pid
    else
        console.log 'Started.'

exports.startFailed = (err) ->
    console.log err
    process.exit 1

# This can fail if the pidfile becomes unwriteable after status() but before
# daemon.lock(). It's a race condition, but it's a hard one to fix.
exports.start = ({ pidfile, logfile, run, success, failure }) ->
    success or= exports.startSucceeded
    failure or= exports.startFailed
    logfile or= '/dev/null'

    start = (err) ->
        return failure(err) if err
        fs.open logfile, 'a+', 0666, (err, fd) ->
            return failure(err) if err
            success()
            pid = daemon.start(logfile)
            daemon.lock(pidfile)
            run()

    exports.status pidfile, (st) ->
        if st.pid
            success st.pid, true
        else if st.exists
            fs.unlink pidfile, start
        else
            start()

exports.stopped = (killed) ->
    if killed
        console.log 'Stopped.'
    else
        console.log 'Not running.'
    process.exit 0

exports.hardKiller = (timeout = 2000) ->
    (pid, cb) ->
        signals = ['TERM', 'INT', 'QUIT', 'KILL']
        tryKill = ->
            sig = "SIG#{ signals[0] }"
            try
                # throws when the process no longer exists
                process.kill pid, sig
                signals.shift() if signals.length > 1
                setTimeout (-> tryKill sig), timeout
            catch e
                cb(signals.length < 4)
        tryKill()

exports.softKiller = (timeout = 2000) ->
    (pid, cb) ->
        sig = "SIGTERM"
        tryKill = ->
            try
                # throws when the process no longer exists
                process.kill pid, sig
                console.log "Waiting for pid " + pid
                sig = 0 if sig != 0
                first = false
                setTimeout tryKill, timeout
            catch e
                cb(sig == 0)
        tryKill()

exports.stop = (pidfile, cb = exports.stopped, killer = exports.hardKiller(2000)) ->
    exports.status pidfile, ({pid}) ->
        if pid
            killer pid, (killed) ->
                fs.unlink pidfile, -> cb(killed)
        else
            cb false

exports.simple = ({pidfile, logfile, command, run, killer}) ->
    command or= process.argv[2]
    killer or= null
    start = -> exports.start { pidfile, logfile, run }
    switch command
        when 'start'  then start()
        when 'stop'   then exports.stop pidfile, null, killer
        when 'status' then exports.status pidfile
        when 'restart', 'force-reload'
            exports.stop pidfile, start, killer
        when 'try-restart'
            exports.stop pidfile, (killed) ->
                if killed
                    exports.start { pidfile, logfile, run }
                else
                    console.log 'Not running.'
                    process.exit 1
        else
            console.log 'Command must be one of: ' +
                'start|stop|status|restart|force-reload|try-restart'
            process.exit 1
