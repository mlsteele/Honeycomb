# Distributed message passing network.
# Messages are not guaranteed delivery.
# Messages may be delivered multiple times through multiple paths.
#
# This file abstract base classes with common functionality among distribution
# backends.

logger = require './logger'


# Local node handle.
# Abstract base class.
class BaseLocalNode
  constructor: (@node_id="node|?|uuid.v4()") ->
    # list of `Pod`s
    @pods = {}
    # list of instances derived from `BaseExtNode`
    @ext_nodes = {}

  add_pod: (pod) ->
    unless pod.pod_id?
      throw new Error "pod missing pod_id"
    @pods[pod.pod_id] = pod

  add_ext_node: (ext_node) ->
    unless ext_node.node_id?
      throw new Error "ext_node missing node_id"
    @ext_nodes[ext_node.node_id] = ext_node

  # Send a message to the `Pod` with `pod_id`.
  # Returns `false` if the `Pod` could not be found.
  msg_pod: (pod_id, msg) ->
    # search in this node
    local_pod = @pods[pod_id]
    if local_pod?
      logger.debug "found pod_id in local node"
      local_pod.recv_msg msg
    else
      logger.warn "BaseLocalNode.msg_pod failed to pass message to pod@#{pod_id}"
      return false


# Representation of an external node.
# Abstract base class.
class BaseExtNode
  constructor: (@node_id) ->
    unless typeof @node_id is 'string'
      throw new Error "BaseExtNode missing node_id (#{@node_id})"

    # `pods_relations` is a mapping from `pod_id`s to information
    # on how the pod is related to this node. Each entry has
    # a `type` attribute describing the type of connection.
    # Besides `type`, each node implementation can define
    # its own relation structure.
    @pods_relations = {}

  # Send a message through the external node
  msg_pod: (pod_id, msg) ->
    throw new Error "BaseExtNode.msg_pod must be overridden."

  # Update the representation of what the external node knows.
  # Usually will involve fetching from a remote.
  update: ->
    throw new Error "BaseExtNode.update must be overridden."

module.exports =
  BaseLocalNode: BaseLocalNode
  BaseExtNode:   BaseExtNode
