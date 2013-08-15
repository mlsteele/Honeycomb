# TCP node communicating over json-over-tpc.
# Persistent connections allow for NAT hole-punching.
#
# External pod relations have the fields:
# - `type` is 'tcp'
# - `hops` is the number of hops away the pod is.
#   Currently the maximum stored hops is 0.

logger = require './logger'
uuid = require 'node-uuid'
{EventEmitter} = require 'events'
{BaseLocalNode, BaseExtNode} = require './nodebase'


class TCPLocalNode extends BaseLocalNode
  constructor: ({@hostname, @port}) ->
    unless typeof @port is 'number'
      throw new Error "Port is not a number (#{@port})"

    super "node|tcp|#{@hostname}:#{@port}"

  # Send a message to the `Pod` with `pod_id`.
  # Returns `false` if the `Pod` could not be found.
  msg_pod: (pod_id, msg) ->
    # Delegate to superclass, fall back to this
    # implementation if super cannot find pod.
    return unless (super pod_id, msg) is false

    # Search through external nodes.
    for ext_node_id, ext_node of @ext_nodes
      relation = ext_node.pods_relations[pod_id]
      if relation?.type is 'tcp'
        ext_node.msg_pod pod_id, msg
        return true

    return false


class TCPExtNode extends BaseExtNode
  constructor: ({@hostname, @port}) ->
    unless typeof @port is 'number'
      throw new Error "Port is not a number (#{@port})"
    unless typeof @hostname is 'string'
      throw new Error "Hostname is not a string (#{@hostname})"

    # extend EventEmitter
    EventEmitter.call this

    super "node|exttcp|#{@hostname}:#{@port}"

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
