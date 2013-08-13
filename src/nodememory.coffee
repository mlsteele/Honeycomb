# In memory nodes.
# Minimal working implementation of base nodes.
# Mosty useless, except for testing locally.

logger = require './logger'
uuid = require 'node-uuid'
{BaseLocalNode, BaseExtNode} = require './nodebase'


class MemLocalNode extends BaseLocalNode
  constructor: ->
    @node_id = uuid.v4()
    super

  # Send a message to the `Pod` with `pod_id`.
  # Returns `false` if the `Pod` could not be found.
  msg_pod: (pod_id, msg) ->
    # Delegate to superclass, fall back to this
    # implementation if super cannot find pod.
    return unless (super pod_id, msg) is false

    @ext_nodes.map (ext_node_id, ext_node) ->
      relation = ext_node.pods_relation[pod_id]
      if relation?.type is 'mem'
        ext_node.msg_pod pod_id, msg


class MemExtNode extends BaseExtNode
  constructor: (@local_node) ->
    unless typeof @local_node.msg_pod is 'function'
      throw new Error "MemExtNode.local_node missing msg_pod function"

  msg_pod: (pod_id, msg) ->
    @local_node.msg_pod pod_id, msg

  update: ->
