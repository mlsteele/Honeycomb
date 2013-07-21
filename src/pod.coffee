uuid = require 'node-uuid'

class Pod
  constructor: (@pod_id) ->
    @pod_id ?= uuid.v4()

  recv_msg: (msg) ->
    console.log "pod #{@pod_id} received message '#{msg}'"

module.exports = Pod
