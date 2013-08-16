# TCP node communicating over json-over-tpc.
# Persistent connections allow for NAT hole-punching.
#
# External pod relations have the fields:
# - `type` is 'tcp'
# - `hops` is the number of hops away the pod is.
#   Currently the maximum stored hops is 0.

logger = require './logger'
uuid = require 'node-uuid'
jot = require 'json-over-tcp'
{EventEmitter} = require 'events'
{BaseLocalNode, BaseExtNode} = require './nodebase'


class TCPLocalNode extends BaseLocalNode
  # `hostname` and `port` to listen on. `hostname` is optional.
  constructor: ({@hostname, @port}) ->
    unless typeof @port is 'number'
      throw new Error "Port is not a number (#{@port})"

    super "node|tcp|#{@hostname}:#{@port}"

  listen: ->
    @server = jot.createServer ->
    @server.on 'connection', (socket) =>
    @socket.on 'error', => logger.log "socket error"
    @socket.on 'close', => logger.log "socket close"
    @socket.on 'error', => logger.log "socket data"
    # socket.destroy()

    @server.listen @port, @hostname
    @_is_listening = yes

  is_listening: -> @_is_listening

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
        # only try one route
        return true

    return false


# `TCPExtNode` also extends `EventEmitter` and emits
# `msg_pod(pod_id, msg)` when the external socket sends a message here.
class TCPExtNode extends BaseExtNode
  constructor: ({@hostname, @port}) ->
    unless typeof @port is 'number'
      throw new Error "Port is not a number (#{@port})"
    unless typeof @hostname is 'string'
      throw new Error "Hostname is not a string (#{@hostname})"

    # extend EventEmitter
    EventEmitter.call this

    super "node|exttcp|#{@hostname}:#{@port}"

  # attach a json socket
  # `socket` must be a json-over-tcp socket.
  attach_socket: (socket) ->
    # close existing socket
    if @socket? then socket.close()
    @socket = socket

    # attach listeners
    socket.on 'close', =>
      @socket = undefined

    socket.on 'error', =>
      logger.error "tcp socket error"
      @socket = undefined

    socket.on 'data', (data) =>
      unless socket is @socket
        logger.error "got data from old socket"
      logger.highest "socket got data!"

      if data.cmd is 'msg_pod'
        @emit 'msg_pod', msg.pod_id, msg.msg
        return

      if data.cmd is 'update_request'
        logger.debug "received update request"
        @emit 'update_request'
        return

  connect: ->
    socket = jot.connect @port, ->
      socket.removeListener 'error', pre_attach_error
      @attach_socket socket
    pre_attach_error = =>
      console.log arguments
      logger.error "error in connecting socket."
    socket.on 'error', pre_attach_error

  is_connected: -> @socket?

  msg_pod: (pod_id, msg) ->
    if @socket?
      @socket.write
        cmd: 'msg_pod'
        pod_id: pod_id
        msg: msg
    else
      logger.warn "TCPExtNode could not 'msg_pod' without socket."

  update: (cb) ->
    if @socket?
      @socket.write
        cmd: 'update_request'
    else
      logger.warn "TCPExtNode could not 'update' without socket."


module.exports =
  TCPLocalNode: TCPLocalNode
  TCPExtNode:   TCPExtNode
