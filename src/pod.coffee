uuid = require 'node-uuid'
logger = require './logger'

class Pod
  constructor: ->
    @pod_id = "pod:#{uuid.v4()}"
    logger.debug "created pod@#{@pod_id}"
    @messages = []

  recv_msg: (msg) ->
    @messages.push msg
    logger.debug "pod #{@pod_id} received message '#{msg}'"

module.exports = Pod
