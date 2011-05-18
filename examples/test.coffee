init = require 'init'

snore = true
snorlax = ->
    console.log if snore then "Snore..." else "Lax..."
    snore = not snore


start = ->
    interval = setInterval snorlax, 4000
    process.on 'SIGTERM', -> console.log 'Mmm,mm.'
    process.on 'SIGINT',  -> console.log 'Mmmm!.'
    process.on 'SIGQUIT', ->
        console.log 'Mrpmph!'
        clearInterval interval

init.simple
    pidfile : './test.pid'
    logfile : './test.log'
    run     : start
