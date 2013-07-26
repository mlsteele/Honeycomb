http = require 'http'
request = require 'request'
express = require 'express'
{LocalNode, ForeignNode} = require './netbase'
{parseHost} = require './helpers'
logger = require './logger'

class HTTPLocalNode extends LocalNode
  # * `cb` is called after the server initializes.
  constructor: (@port, @hostname) ->
    unless @port?
      throw new Error "Missing port argument for constructor."
    unless typeof @port is 'number'
      throw new Error "Bad port #{@port}"

    super()

    @_setup_app()
    @server = http.createServer @app

  listen: (cb) ->
    logger.debug "HTTPLocalNode listening on #{@hostname}:#{@port}"
    @server.listen @port, @hostname, cb

  # send a message to the pod.
  # returns false if the pod could not be found.
  msg_pod: (pod_id, msg) ->
    # delegate to superclass, fall back to this implementation
    return unless (super pod_id, msg) is false

    # search in foreign http nodes
    foreign_http_nodes = (fn for fn_id, fn of @foreign_nodes when fn instanceof HTTPForeignNode)
    for fn in foreign_http_nodes
      for pod_id, pod_info of fn.pods_info
        logger.debug "found pod_id in HTTPForeignNode with type #{pod_info.type}"
        if pod_info.type is 'local'
          # only try the first match
          return fn.msg_pod pod_id, msg

    logger.error "HTTPLocalNode.msg_pod failed to pass message to pod@#{pod_id}."
    false


  # Start a TCP server for issuing a small set of commands to the node.
  # Not tremendously secure.
  listen_repl: (port, hostname) ->
    net = require 'net'
    repl = require 'repl'

    repl_server = net.createServer (socket) =>
      help_text = """
        \nHTTPLocalNode remote control
        \nUsage:
          help                    - display this help
          info                    - info about this node
          add IP:PORT             - add a remote http node
          msg pod_id message body - message a pod\n\n
      """

      socket.write help_text

      repl.start
        prompt: "HTTPLocalNode> "
        input: socket
        output: socket
        ignoreUndefined: true
        eval: (cmd, context, filename, callback) =>
          response = undefined
          if cmd.match /help/
            socket.write help_text
          else if cmd.match /info/
            socket.write "this is an HTTPLocalNode at #{@hostname}:#{@port}\n"
            socket.write "with a pod #{pod.pod_id}\n" for pod in @pods
          else if cmd.match /add/
            socket.write "'add' not implemented.\n"
          else if cmd.match /msg/
            match = cmd.match /msg (.*) (.*)/
            [x, pod_id, msg] = match
            response = "sending to #{pod_id} message: '#{msg}'"
            @msg_pod pod_id, msg
            socket.write "ok.\n"
          callback null, response

    repl_server.listen port, hostname

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

      # TODO send foreign pods
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
      logger.debug req.body

      publisher_port_str = req.body.port
      unless publisher_port_str?
        logger.warn "received publish_node request without publisher 'port'"
        return res.send 500, "missing publisher 'port'"

      publisher_str = "#{request_hostname}:#{publisher_port_str}"
      publisher = parseHost publisher_str
      unless publisher?
        logger.warn "bad foreign hostname:port #{publisher_str}"
        return res.send 500, "bad foreign hostname:port #{publisher_str}"

      # get or create a foreign entry for the posting node.
      # TODO this logic should be in @add_or_create_foreign_node
      fn = new HTTPForeignNode publisher.hostname, publisher.port
      if fn.node_id of @foreign_nodes
        logger.debug "already have foreign node #{fn.node_id}"
        fn = @foreign_nodes[fn.node_id]
      else
        logger.debug "adding foreign node #{fn.node_id}"
        @add_foreign_node fn

      # ask the node what's new.
      # TODO this logic should be in @on_discover_node
      fn.update()

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
  constructor: (@hostname, @port) ->
    super()
    unless @hostname? and @port?
      throw new Error "Missing host or port argument to constructor."
    unless typeof @port is 'number'
      throw new Error "Bad port #{@port}"

    @node_id = "node:http//:#{@hostname}:#{@port}"

  # send message to foreign pod
  # TODO refactor for nicer request
  msg_pod: (pod_id, msg) ->
    request.post "http://#{@hostname}:#{@port}/msg_pod/#{pod_id}",
      form: msg: msg,
      (error, res, body) =>
        if error isnt null
          logger.error "http error after msg_pod"
          logger.error error

        if res.statusCode isnt 200
          logger.error "http status code #{res.statusCode} received after msg_pod"
          logger.error body

        logger.debug "successful response to http msg_pod"

  # query the foreign node about the net_shape.
  update: (cb) ->
    url = "http://#{@hostname}:#{@port}/internode/net_shape"
    request.get url, (error, res, body) =>
        if error isnt null
          logger.error "http error after querying net_shape"
          logger.error error

        if res.statusCode isnt 200
          logger.error "http status code #{res.statusCode} received after querying net_shape"
          logger.error body

        logger.debug "successful response to querying net_shape"
        logger.debug body

        parsed_body = JSON.parse body
        {pods_info, foreign_nodes} = JSON.parse body
        @pods_info = pods_info
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

        if res.statusCode isnt 200
          logger.error "http status code #{res.statusCode} received after publishing"
          logger.error body

        logger.debug "successful publish"


module.exports =
  HTTPLocalNode: HTTPLocalNode
  HTTPForeignNode: HTTPForeignNode
