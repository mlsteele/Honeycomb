http = require 'http'
express = require 'express'
{LocalNode, ForeignNode} = require './netbase'
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

    # another asks what this node
    # knows about pods
    @app.get '/internode/pods_info', (req, res) =>
      res_data = {}
      for pod in @pods
        res_data[pod.pod_id] = local: true

      res.json res_data

    # another node publishes its existance
    @app.post '/internode/publish_node', (req, res) =>
      logger.debug "recieved publish_node request"
      foreign_host = req.connection.remoteAddress
      foreign_port = req.connection.remotePort
      logger.debug "publish_node request from #{foreign_host}:#{foreign_port}"

      # TODO deduplicate
      fn = new HTTPForeignNode foreign_host, foreign_port
      @add_foreign_node fn
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
    unless @host? and @port?
      throw new Error "Missing host or port argument to constructor."
    unless typeof @port is 'number'
      throw new Error "Bad port #{@port}"

    super()

  # send message to foreign pod
  # TODO refactor for nicer request
  msg_pod: (pod_id, msg) ->
    options =
      hostname: @host
      port: @port
      path: "/msg_pod/#{pod_id}"
      method: 'POST'

    request = http.request options, (res) ->
      logger.debug "recvd response after POSTing to /msg_pod"
      logger.debug "STATUS: " + res.statusCode
      logger.debug "HEADERS: " + JSON.stringify(res.headers)
      # res.setEncoding 'utf8'
      res.on "data", (chunk) ->
        logger.debug "BODY: " + chunk

    request.on 'error', (e) ->
      logger.error "problem with POSTing to /msg_pod"
      logger.error "#{e.message}"

    request.end msg

  # query the foreign node about foreign pods.
  update: (cb) ->
    options =
      hostname: @host
      port: @port
      path: "/internode/pods_info"
      method: 'GET'

    request = http.request options, (res) =>
      logger.debug "recvd response after GETting to /internode/pods_info"
      logger.debug "STATUS: " + res.statusCode
      logger.debug "HEADERS: " + JSON.stringify(res.headers)
      # res.setEncoding 'utf8'

      # buffer full response body
      full_body = ""
      res.on "data", (chunk) -> full_body += chunk
      res.on "end", =>
        @pods_info = JSON.parse full_body
        cb?()

    request.on 'error', (e) ->
      logger.error "problem with GETting to /internode/pods_info"
      logger.error "#{e.message}"

    request.end()

  # publish to the foreign node the existance of this local node
  publish: ->
    options =
      hostname: @host
      port: @port
      path: "/internode/publish_node"
      method: 'POST'

    request = http.request options, (res) =>
      logger.debug "recvd response after POSTing to /internode/publish_node"
      logger.debug "STATUS: " + res.statusCode
      logger.debug "HEADERS: " + JSON.stringify(res.headers)
      # res.setEncoding 'utf8'

    request.on 'error', (e) ->
      logger.error "problem with POSTting to /internode/publish_node"
      logger.error "#{e.message}"

    request.end()


module.exports =
  HTTPLocalNode: HTTPLocalNode
  HTTPForeignNode: HTTPForeignNode
