# Winston Logger

winston = require 'winston'

logger = new winston.Logger
  levels:
    debug: 0
    info: 1
    warn: 2
    error: 3
    highest: 3
  colors:
    debug: 'cyan'
    info: 'green'
    warn: 'yellow'
    error: 'red'
    highest: 'white'
  transports: [
    new winston.transports.Console
      level: 'debug'
      colorize: true
      timestamp: false
  ]


logger.on 'error', (err) ->
  console.error "WINSTON LOGGING ERROR: '#{err}'"

module.exports = logger
