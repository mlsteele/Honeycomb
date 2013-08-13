# HTTP Nodes
# Establish a healing mesh network.
# Does not deal well with NAT (one way connections).

http = require 'http'
request = require 'request'
express = require 'express'
make_slot = require 'callback-slot'
logger = require './logger'
{parseHost, plantInterval} = require './helpers'
{BaseLocalNode, BaseForeignNode} = require './nodebase'
{JSONFile} = require './persistence'

ENABLE_PERSISTENCE = no

class HTTPLocalNode extends BaseLocalNode
  # Does not listen until `listen` is called.
  # * `port` is the port to listen on.
  # * `hostname` is the hostname to listen from (optional).
  constructor: ({@hostname, @port}) ->
    unless @port?
      throw new Error "Missing port argument to constructor."
    unless typeof @port is 'number'
      throw new Error "Port is not a number (#{@port})"

    super "node|http|http://#{@hostname}:#{@port}"

    if ENABLE_PERSISTENCE
      @netfile = new JSONFile "data/net/#{@hostname}:#{@port}.json"
      @netfile.load (error, obj) =>
        unless error is null
          logger.error error.message
          return
        for node_id, {hostname, port} of obj.foreign_nodes
          @discover_node hostname, port, yes

    # setup http server
    @_setup_app()
    @server = http.createServer @app

  listen: (cb) ->
    logger.debug "HTTPLocalNode listening on #{@hostname}:#{@port}"
    @server.listen @port, @hostname, cb

  # Send a message to the `Pod` with `pod_id`.
  # Returns `false` if the `Pod` could not be found.
  msg_pod: (pod_id, msg) ->
    # Delegate to superclass, fall back to this
    # implementation if super cannot find pod.
    return unless (super pod_id, msg) is false

    # Search through external nodes.
    for ext_node_id, ext_node of @ext_nodes
      relation = ext_node.pods_relations[pod_id]
      if relation?.type is 'http'
        ext_node.msg_pod pod_id, msg
        return true

    return false

  # called when discovering a (possibly new) foreign node address.
  # * `poll` is a boolean determining whether to begin
  #   polling the discovered node.
  discover_node: (hostname, port, poll) ->
    fn = new HTTPForeignNode hostname, port, this
    if @foreign_nodes[fn.node_id]?
      logger.debug "rediscovered node #{fn.node_id}"
      return
    else
      logger.debug "adding new node #{fn.node_id}"
      @add_foreign_node fn
      fn.publish this
      fn.update()
      fn.poll poll, this

      if ENABLE_PERSISTENCE
        save_data = foreign_nodes: {}

        # format foreign http nodes
        for node_id, foreign_node of @foreign_nodes
          if foreign_node instanceof HTTPForeignNode
            save_data.foreign_nodes[node_id] =
              hostname: foreign_node.hostname
              port: foreign_node.port

        @netfile.save save_data, (error) ->
          unless error is null
            logger.error error.message
            return

  _setup_app: ->
    @app = express()
    @app.use express.bodyParser()

    # from https://gist.github.com/shesek/4651267
    rawBufferMiddleware = (req, res, next) ->
      req.raw_body = ""
      req.on 'data', (chunk) -> req.raw_body += chunk
      req.on 'end', next

    # Responds with this node's model of the network.
    # Including pod and foreign node info
    @app.get '/internode/net_shape', (req, res) =>
      res_data =
        # pods_info goes right into ForeignNode.pods_info
        pods_info: {}
        foreign_nodes: {}

      # TODO should this send foreign pods?
      for pod in @pods
        res_data.pods_info[pod.pod_id] =
          type: 'local'

      logger.debug "reporting on HTTPForeignNode's"
      for fn_id, fn of @foreign_nodes when fn instanceof HTTPForeignNode
        logger.debug "reporting on HTTPForeignNode #{fn.node_id}"
        res_data.foreign_nodes[fn.node_id] =
          hostname: fn.hostname
          port: fn.port

      res.json res_data

    # another node publishes its existance
    @app.post '/internode/publish_node', (req, res) =>
      request_hostname = req.connection.remoteAddress
      request_port = req.connection.remotePort

      logger.debug "publish_node request from #{request_hostname}:#{request_port}"
      logger.debug "request body #{JSON.stringify req.body}"

      publisher_port_str = req.body.port
      unless publisher_port_str?
        logger.warn "received publish_node request without publisher 'port'"
        return res.send 500, "missing publisher 'port'"

      publisher_str = "#{request_hostname}:#{publisher_port_str}"
      publisher = parseHost publisher_str
      unless publisher?
        logger.warn "bad foreign hostname:port #{publisher_str}"
        return res.send 500, "bad foreign hostname:port #{publisher_str}"
      logger.debug "published host #{publisher.hostname}:#{publisher.port}"

      @discover_node publisher.hostname, publisher.port, yes

      res.send 200, "thanks for the publish."

    @app.post '/msg_pod/:pod_id', (req, res) =>
      target_pod_id = req.params.pod_id
      logger.debug "received request to msg_pod #{target_pod_id}"
      unless req.body.msg?
        logger.warn "received msg_pod request without message"
        res.send 400, "missing message body."
      msg = req.body.msg
      @msg_pod target_pod_id, msg
      res.send 200, "message passed."


# representation of an external node
class HTTPForeignNode extends ForeignNode
  constructor: (@hostname, @port, @local_node) ->
    super()
    unless @hostname?
      throw new Error "Missing hostname argument to constructor."
    unless typeof @port is 'number'
      throw new Error "Bad port #{@port}"
    unless @local_node instanceof HTTPLocalNode
      throw new Error "Missing local node reference"

    @node_id = "node:http://#{@hostname}:#{@port}"

    @poll_slot = make_slot()
    @poll_interval_id = undefined

  # send message to foreign pod
  # TODO refactor for nicer request
  msg_pod: (pod_id, msg) ->
    request.post "http://#{@hostname}:#{@port}/msg_pod/#{pod_id}",
      form: msg: msg,
      (error, res, body) =>
        if error isnt null
          logger.error "http error after msg_pod"
          logger.error error
          return

        if res.statusCode isnt 200
          logger.error "http status code #{res.statusCode} received after msg_pod"
          logger.error body
          return

        logger.debug "successful response to http msg_pod"

  # Enable or disable update polling.
  # When polling is enabled, the `ForeignNode` will periodically
  # poll for net_shape updates as well as publish to foreign nodes.
  # * `enable` is a boolean determing whether to enable polling
  # * `local_node` is the `HTTPLocalNode` to publish and
  #   tell about newly discovered nodes.
  poll: (enable) ->
    POLL_INTERVAL_MS = 10 * 1000

    # stop execution of existing poll
    clearInterval @poll_interval_id
    @poll_slot.clear()

    if enable
      # register new poll into slot and start timer
      @poll_interval_id = plantInterval POLL_INTERVAL_MS, @poll_slot =>
        @publish @local_node
        @update()

  # query the foreign node about the net_shape.
  # * `cb` is a callback which is fired on response.
  update: (cb) ->
    url = "http://#{@hostname}:#{@port}/internode/net_shape"
    request.get url, (error, res, body) =>
      if error isnt null
        logger.error "http error after querying net_shape"
        logger.error error
        cb? error
        return

      if res.statusCode isnt 200
        logger.error "http status code #{res.statusCode} received after querying net_shape"
        logger.error body
        cb? new Error res.statusCode
        return

      logger.debug "successful response to querying net_shape"
      logger.debug body
      parsed_body = JSON.parse body
      {pods_info, foreign_nodes} = JSON.parse body

      @pods_info = pods_info

      for node_id, {hostname, port} of foreign_nodes
        @local_node.discover_node hostname, port, yes

      cb? null

  # publish to the foreign node the existance of this local node
  publish: (local_node) ->
    unless local_node?.port?
      throw new Error "local_node missing port."

    request.post "http://#{@hostname}:#{@port}/internode/publish_node",
      form: port: local_node.port,
      (error, res, body) =>
        if error isnt null
          logger.error "http error after publishing"
          logger.error error
          return

        if res.statusCode isnt 200
          logger.error "http status code #{res.statusCode} received after publishing"
          logger.error body
          return

        logger.debug "successful publish"


module.exports =
  HTTPLocalNode: HTTPLocalNode
  HTTPForeignNode: HTTPForeignNode
