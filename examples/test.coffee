init = require 'init'

snore = true
snorlax = ->
    console.log if snore then "Snore..." else "Lax..."
    snore = not snore

init.simple
    pidfile : './test.pid'
    logfile : './test.log'
    run     : -> setInterval snorlax, 4000
