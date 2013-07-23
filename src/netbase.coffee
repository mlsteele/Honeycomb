# Distributed network message passing.
#
# Messages are not guaranteed delivery.

http = require 'http'
uuid = require 'node-uuid'
{plantTimeout} = require './helpers'
logger = require './logger'


class LocalNode
  constructor: ->
    @pods = []
    # list of ForeignNode's
    @foreign_nodes = {}

  add_pod: (pod) ->
    @pods.push pod

  add_foreign_node: (foreign_node) ->
    unless foreign_node.node_id?
      throw new Error "foreign_node missing node_id"
    @foreign_nodes[foreign_node.node_id] = foreign_node

  # send a message to the pod.
  # returns false if the pod could not be found.
  msg_pod: (pod_id, msg) ->
    # search in this node
    local_pod = (p for p in @pods when p.pod_id is pod_id)[0]
    if local_pod
      logger.debug "found pod_id in local node"
      return local_pod.recv_msg msg

    logger.warn "LocalNode.msg_pod failed to pass message to pod@#{pod_id}"
    false


# representation of an external node
# abstract base class
class ForeignNode
  constructor: ->
    # @pods_info is a mapping from pod_id's to information on how the pod is related
    # to this node. Each entry has a 'type' attribute describing the connection.
    #
    # Example illustrating format:
    #
    #     @pods_info = {
    #       'pod_id_1':
    #         # pod connected locally to the node
    #         type: 'local'
    #       'pod_id_2':
    #         # pod connected through another node via http
    #         type: 'http'
    #         # number of hops away, minimum 1 (0 would be local)
    #         # `hops` is optional.
    #         hops: 1
    #     }

    @node_id = "node:dummy:#{uuid.v4()}"
    @pods_info = {}

  msg_pod: (pod_id, msg) ->
    throw new Error "ForeignNode.msg_pod must be overridden."

  # add_pod_id: (pod_id) ->
  #   throw new Error "ForeignNode.add_pod_id must be overridden."

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
