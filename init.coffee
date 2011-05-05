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
            pid = daemon.start(fd)
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

exports.stop = (pidfile, cb = exports.stopped) ->
    exports.status pidfile, ({pid}) ->
        if pid
            n = 0
            do ->
                signal = if n > 3 then 'SIGKILL' else 'SIGTERM'
                try
                    process.kill pid
                    n += 1
                    setTimeout arguments.callee, 1000
                catch e
                    fs.unlink pidfile, -> cb(n > 0)
        else
            cb false

exports.simple = ({pidfile, logfile, command, run}) ->
    command or= process.argv[2]
    start = -> exports.start { pidfile, logfile, run }
    switch command
        when 'start'  then start()
        when 'stop'   then exports.stop pidfile
        when 'status' then exports.status pidfile
        when 'restart', 'force-reload'
            exports.stop pidfile, start
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
