# Distributed network message passing.
# Messages are not guaranteed delivery.

# uuid = require 'node-uuid'
http = require 'http'
{plantTimeout} = require './helpers'
logger = require './logger'


class LocalNode
  constructor: ->
    # @node_id = "node:#{uuid.v4()}"
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
      logger.debug "found pod_id in local node"
      return local_pod.recv_msg msg

    # search in foreign nodes
    for foreign_node in @foreign_nodes
      foreign_pod_id = (fp_id for fp_id of foreign_node.pods_info when fp_id is pod_id)[0]
      if foreign_pod_id
        logger.debug "found pod_id in foreign node"
        # only try the first match
        return foreign_node.msg_pod foreign_pod_id, msg

    logger.warn "could not pass message to #{pod_id}."


# representation of an external node
# abstract base class
class ForeignNode
  constructor: ->

    # @pods_info is a mapping from pod_id's to information on how the pod is related
    # to this node.
    #
    # A pod_id will only be a key in @pods_info if the foreign node knows
    # something about it.
    #
    # Keys for each entry can be one of
    # * `dummy` dummy for testing (possible value: true)
    # * `local` pod connected locally to the pod (possible value: true)
    @pods_info = {}

  msg_pod: (pod_id, msg) ->
    throw new Error "ForeignNode.msg_pod must be overridden."

  add_pod_id: (pod_id) ->
    throw new Error "ForeignNode.add_pod_id must be overridden."

  # update the representation of what the foreign node knows.
  update: ->
    throw new Error "ForeignNode.update must be overridden."


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
