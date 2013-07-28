http = require 'http'
express = require 'express'
logger = require './logger'

class HTTPPodView
  constructor: (@pod) ->
    @messages = []
    @pod.on 'recv_msg', (msg) =>
      @messages.push msg

    @_setup_app()
    @server = http.createServer @app

  attach_node: (@local_node) ->
    logger.debug "HTTPPodView attaching local node."

  listen: (@port, @host) ->
    unless typeof @port is 'number'
      throw new Error "Bad port #{@port}"

    @server.listen @port, @host, =>
      logger.debug "HTTPPodView listening on #{@host}:#{@port}"

  _setup_app: ->
    @app = express()
    @app.use express.bodyParser()

    @app.get '/check', (req, res) =>
      res.send 200

    @app.get '/', (req, res) =>
      html = """
        <h1>Welcome to your pod</h1>
        <br>
        your pod id is #{@pod.pod_id}
        <br>
        <a href="/messages">messages</a>
      """
      res.send html

    @app.get '/messages', (req, res) =>
      html = "<h1>/messages</h1>"
      if @messages.length
        html += "Here are your messages:"
      else
        html += "You have no messages. :("
      html += "<br>"
      for msg in @messages
        html += "<p>#{msg}</p>"
      res.send html

    @app.get '/send', (req, res) =>
      html = """
      <h1>Send a message.</h1>
      <form name="input" action="/api/msg_pod" method="post">
          recipient pod id: <input type="text" name="pod_id"><br>
          message: <textarea name="msg_body"></textarea><br>
          <input type="submit" value="Send">
      </form>
      """
      res.send html

    @app.post '/api/msg_pod', (req, res) =>
      unless @local_node?
        logger.warn "trying to send message without local node"
        return res.send 500, "no local_node"

      unless req.body.pod_id? and req.body.msg_body?
        logger.debug "received invalid post request to /api/msg_pod"
        return res.send 400, "missing post parameters"

      logger.debug "pod view sending message."
      @local_node.msg_pod req.body.pod_id.trim(), req.body.msg_body
      res.send 200, "message passed."


module.exports =
  HTTPPodView: HTTPPodView
