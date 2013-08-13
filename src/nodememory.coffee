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
    @node_id = "uuid.v4()"
    super

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
        return true

    return false


class MemExtNode extends BaseExtNode
  constructor: (@local_node) ->
    unless typeof @local_node?.msg_pod is 'function'
      throw new Error "MemExtNode.local_node missing msg_pod function."
    unless typeof @local_node?.node_id is 'string'
      throw new Error "MemExtNode.local_node missing node_id."
    super "node|extmem|#{@local_node.node_id}"

  msg_pod: (pod_id, msg) ->
    @local_node.msg_pod pod_id, msg

  update: ->
    @pods_relations = {}
    for pod_id of @local_node.pods
      @pods_relations[pod_id] =
        type: 'mem'
        hops: 0


module.exports =
  MemLocalNode: MemLocalNode
  MemExtNode:   MemExtNode
