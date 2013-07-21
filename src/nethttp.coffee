http = require 'http'
express = require 'express'
{LocalNode, ForeignNode} = require './netbase'

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
            console.log cmd
            console.log match
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
    bufferMiddleware = (req, res, next) ->
      req.raw_body = ""
      req.on 'data', (chunk) -> req.raw_body += chunk
      req.on 'end', next

    @app.get '/check', (req, res) =>
      res.send 200

    @app.post '/msg_pod/:pod_id', bufferMiddleware, (req, res) =>
      target_pod_id = req.params.pod_id
      msg = req.raw_body
      @msg_pod target_pod_id, msg
      res.send "message sent."


# representation of an external node
class HTTPForeignNode extends ForeignNode
  constructor: (@port, @host) ->
    unless @port?
      throw new Error "Missing port argument for constructor."
    unless typeof @port is 'number'
      throw new Error "Bad port #{@port}"

    super()

  msg_pod: (pod_id, msg) ->
    options =
      hostname: @host
      port: @port
      path: "/msg_pod/#{pod_id}"
      method: 'POST'

    request = http.request options, (res) ->
      console.log "STATUS: " + res.statusCode
      console.log "HEADERS: " + JSON.stringify(res.headers)

      res.setEncoding 'utf8'

      res.on "data", (chunk) ->
        console.log "BODY: " + chunk

    request.on 'error', (e) ->
      console.log "problem with request: #{e.message}"

    # write data to request body
    request.write msg
    request.end()

  fetch_pod_ids: ->
    throw "not implemented"


module.exports =
  HTTPLocalNode: HTTPLocalNode
  HTTPForeignNode: HTTPForeignNode
