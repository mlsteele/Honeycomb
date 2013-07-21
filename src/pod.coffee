uuid = require 'node-uuid'

class Pod
  constructor: ->
    @pod_id = "pod:#{uuid.v4()}"
    @messages = []

  recv_msg: (msg) ->
    @messages.push msg
    console.log "pod #{@pod_id} received message '#{msg}'"

module.exports = Pod
