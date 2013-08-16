# In memory nodes.
# Minimal working implementation of base nodes.
# Mosty useless, except for testing locally.
#
# External pod relations have the fields:
# - `type` is 'mem'
# - `hops` is the number of hops away the pod is.
#   Currently the maximum stored hops is 0.

logger = require './logger'
uuid = require 'node-uuid'
{BaseLocalNode, BaseExtNode} = require './nodebase'


class MemLocalNode extends BaseLocalNode
  constructor: ->
    super "node|mem|#{uuid.v4()}"

  # Send a message to the `Pod` with `pod_id`.
  # Returns `false` if the `Pod` could not be found.
  msg_pod: (pod_id, msg) ->
    # Delegate to superclass, fall back to this
    # implementation if super cannot find pod.
    return unless (super pod_id, msg) is false

    # Search through external nodes.
    for ext_node_id, ext_node of @ext_nodes
      relation = ext_node.pods_relations[pod_id]
      if relation?.type is 'mem'
        ext_node.msg_pod pod_id, msg
        # only try one route
        return true

    return false


class MemExtNode extends BaseExtNode
  # `ext_local_node` is the node this `MemExtNode` points to.
  constructor: (@ext_local_node) ->
    unless typeof @ext_local_node?.msg_pod is 'function'
      throw new Error "MemExtNode.ext_local_node missing msg_pod function."
    unless typeof @ext_local_node?.node_id is 'string'
      throw new Error "MemExtNode.ext_local_node missing node_id."
    super "node|extmem|#{@ext_local_node.node_id}"

  msg_pod: (pod_id, msg) ->
    @ext_local_node.msg_pod pod_id, msg

  update: ->
    # clear relations
    @pods_relations = {}

    # collect from external direct connections.
    for pod_id of @ext_local_node.pods
      @pods_relations[pod_id] =
        type: 'mem'
        hops: 0 # 0 hops from the external node.

    # collect from externals indirect knowledge.
    for ext_node_id, ext_node of @ext_local_node.ext_nodes
      for pod_id, relation of ext_node.pods_relations
        if relation.type is 'mem'

          unless relation.hops?
            throw new Error "relation missing hops."

          if pod_id of @pods_relations
            hops = Math.min @pods_relations[pod_id].hops, relation.hops + 1
          else
            hops = relation.hops + 1

          logger.highest hops

          @pods_relations[pod_id] =
            type: 'mem'
            hops: hops


module.exports =
  MemLocalNode: MemLocalNode
  MemExtNode:   MemExtNode
