{EventEmitter} = require 'events'
uuid = require 'node-uuid'
logger = require './logger'

class Pod extends EventEmitter
  constructor: ->
    @pod_id = "pod:#{uuid.v4()}"
    logger.debug "created pod@#{@pod_id}"

  recv_msg: (msg) ->
    logger.debug "pod #{@pod_id} received message '#{msg}'"
    @emit 'recv_msg', msg


module.exports = Pod
