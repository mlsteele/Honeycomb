http = require 'http'
request = require 'request'
express = require 'express'
{LocalNode, ForeignNode} = require './netbase'
{parseHost} = require './helpers'
logger = require './logger'

class HTTPLocalNode extends LocalNode
  # * `cb` is called after the server initializes.
  constructor: (@port, @host) ->
    unless @port?
      throw new Error "Missing port argument for constructor."
    unless typeof @port is 'number'
      throw new Error "Bad port #{@port}"

    super()

    @_setup_app()
    @server = http.createServer @app

  listen: (cb) ->
    logger.debug "HTTPLocalNode listening on #{@host}:#{@port}"
    @server.listen @port, @host, cb

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
  listen_repl: (port, host) ->
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
            socket.write "this is an HTTPLocalNode at #{@host}:#{@port}\n"
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

    repl_server.listen port, host

  _setup_app: ->
    @app = express()
    @app.use express.bodyParser()

    # from https://gist.github.com/shesek/4651267
    rawBufferMiddleware = (req, res, next) ->
      req.raw_body = ""
      req.on 'data', (chunk) -> req.raw_body += chunk
      req.on 'end', next

    @app.get '/check', (req, res) =>
      res.send 200

    # Responds with this node's model of the network.
    # Including pod and foreign node info
    @app.get '/internode/net_shape', (req, res) =>
      res_data =
        # pods_info goes right into ForeignNode.pods_info
        pods_info: {}
        foreign_nodes: {}

      for pod in @pods
        res_data.pods_info[pod.pod_id] =
          type: 'local'

      logger.debug "reporting on HTTPForeignNode's"
      for fn_id, fn of @foreign_nodes when fn instanceof HTTPForeignNode
        logger.debug "reporting on HTTPForeignNode #{fn.node_id}"
        res_data.foreign_nodes[fn.node_id] =
          host: fn.host
          port: fn.port

      res.json res_data

    # another node publishes its existance
    @app.post '/internode/publish_node', (req, res) =>
      logger.debug "recieved publish_node request"
      foreign_host = req.connection.remoteAddress
      foreign_port = req.connection.remotePort
      logger.debug "publish_node request from #{foreign_host}:#{foreign_port}"

      console.log req.body

      publisher_port_str = req.body.port
      unless publisher_port_str?
        logger.warn "received publish_node request without publisher 'port'"
        return res.send 500, "missing publisher 'port'"

      publisher_str = "#{foreign_host}:#{publisher_port_str}"
      publisher = parseHost publisher_str
      unless publisher?
        logger.warn "bad foreign host:port #{publisher_str}"
        return res.send 500, "bad foreign host:port #{publisher_str}"

      # ensure a foreign entry for the posting node.
      fn = new HTTPForeignNode publisher.host, publisher.port
      if fn.node_id of @foreign_nodes
        logger.debug "already have foreign node #{fn.node_id}"
        fn = @foreign_nodes[fn.node_id]
      else
        logger.debug "adding foreign node #{fn.node_id}"
        @add_foreign_node fn

      # ask the node what's new.
      fn.update()

      res.send 200

    @app.post '/msg_pod/:pod_id', rawBufferMiddleware, (req, res) =>
      target_pod_id = req.params.pod_id
      msg = req.raw_body
      @msg_pod target_pod_id, msg
      res.send "message sent."


# representation of an external node
class HTTPForeignNode extends ForeignNode
  constructor: (@host, @port) ->
    super()
    unless @host? and @port?
      throw new Error "Missing host or port argument to constructor."
    unless typeof @port is 'number'
      throw new Error "Bad port #{@port}"

    @node_id = "node:http//:#{host}:#{port}"

  # send message to foreign pod
  # TODO refactor for nicer request
  msg_pod: (pod_id, msg) ->
    options =
      hostname: @host
      port: @port
      path: "/msg_pod/#{pod_id}"
      method: 'POST'

    req = http.request options, (res) ->
      logger.debug "recvd response after POSTing to /msg_pod"
      logger.debug "STATUS: " + res.statusCode
      logger.debug "HEADERS: " + JSON.stringify(res.headers)
      # res.setEncoding 'utf8'
      res.on "data", (chunk) ->
        logger.debug "BODY: " + chunk

    req.on 'error', (e) ->
      logger.error "problem with POSTing to /msg_pod"
      logger.error "#{e.message}"

    req.end msg

  # query the foreign node about foreign pods.
  update: (cb) ->
    options =
      hostname: @host
      port: @port
      path: "/internode/net_shape"
      method: 'GET'

    req = http.request options, (res) =>
      logger.debug "recvd response after GETting to /internode/net_shape"
      logger.debug "STATUS: " + res.statusCode
      logger.debug "HEADERS: " + JSON.stringify(res.headers)
      # res.setEncoding 'utf8'

      if res.statusCode isnt 200
        logger.error "Received HTTP status code #{res.statusCode}"
        return cb? new Error "Received HTTP status code #{res.statusCode}"

      # buffer full response body
      full_body = ""
      res.on "data", (chunk) -> full_body += chunk
      res.on "end", =>
        {pods_info, foreign_nodes} = JSON.parse full_body
        @pods_info = pods_info
        cb? null

    req.on 'error', (e) ->
      logger.error "problem with GETting to /internode/net_shape"
      logger.error "#{e.message}"
      cb? new Error "Error in request."

    req.end()

  # publish to the foreign node the existance of this local node
  publish: (local_node) ->
    unless local_node?.port?
      throw new Error "local_node missing port."

    request.post "http://#{@host}:#{@port}/internode/publish_node",
      form: port: local_node.port,
      (error, response, body) ->


module.exports =
  HTTPLocalNode: HTTPLocalNode
  HTTPForeignNode: HTTPForeignNode
