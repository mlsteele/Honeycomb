plantTimeout = (ms, cb) -> setTimeout cb, ms

class Pod
  constructor: (@pod_id) ->

  recv_msg: (msg) ->
    console.log "pod #{@pod_id} received message '#{msg}'"


class LocalNode
  constructor: ->
    @pods = []
    # list of ForeignNode's
    @nodes = []

  add_pod: (pod) ->
    @pods.append pod

  # send a message to the pod.
  # returns false if the pod could not be found.
  msg_pod: (pod_id, msg, cb) ->
    # mock asynchronous callout
    setTimeout 100, ->
      local_pod = (p for p in @pods when p.pod_id is pod_id)[0]
      if local_pod
        local_pod.recv_msg msg
        cb?()


# representation of an external node
class ForeignNode
