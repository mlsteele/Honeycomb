{plantTimeout} = require './helpers'
http = require 'http'

class LocalNode
  constructor: ->
    @pods = []
    # list of ForeignNode's
    @foreign_nodes = []

  add_pod: (pod) ->
    @pods.push pod

  add_foreign_node: (node) ->
    @foreign_nodes.push node

  # send a message to the pod.
  # returns false if the pod could not be found.
  msg_pod: (pod_id, msg) ->
    # search in this node
    local_pod = (p for p in @pods when p.pod_id is pod_id)[0]
    if local_pod
      console.log "found in local"
      return local_pod.recv_msg msg

    # search in friend nodes
    for foreign_node in @foreign_nodes
      foreign_pod_id = (fp_id for fp_id in foreign_node.pod_ids when fp_id is pod_id)[0]
      if foreign_pod_id
        console.log "found in foreign"
        return foreign_node.msg_pod foreign_pod_id, msg

    console.warn "could not pass message to #{pod_id}."


# representation of an external node
class ForeignNode
  constructor: ->
    @pod_ids = []

  msg_pod: (pod_id, msg) ->
    throw "not implemented"

  add_pod_id: (pod_id) ->
    @pod_ids.push pod_id

  fetch_pod_ids: ->
    throw "not implemented"


# local foreign node
# for mocking an external node from a LocalNode
class LocalForeignNode extends ForeignNode
  constructor: (@local_node) ->
    super()

  msg_pod: (pod_id, msg) ->
    @local_node.msg_pod pod_id, msg

  add_local_pod_ids: ->
    (@add_pod_id p.pod_id) for p in @local_node.pods


module.exports =
  LocalNode: LocalNode
  ForeignNode: ForeignNode
  LocalForeignNode: LocalForeignNode
