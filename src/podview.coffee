http = require 'http'
express = require 'express'
handlebars = require 'handlebars'
{JSONFile} = require './persistence'
{plantInterval} = require './helpers'
logger = require './logger'

ENABLE_PERSISTENCE = yes

class HTTPPodView
  constructor: (@pod) ->
    # setup message buffer
    @messages = []
    @pod.on 'recv_msg', (msg) =>
      @messages.push msg

    # TODO factor out plugins.
    # setup pod pings
    @known_pods = {}
    @pod.on 'recv_msg', (msg) =>
      try
        msg_obj = JSON.parse msg
      catch e
        return

      if msg_obj.type is 'pod_ping'
        @discover_pod msg_obj.sender.pod_id
        @known_pods[msg_obj.sender.pod_id] = (new Date).getTime()
        for other_pod_id of msg_obj.others
          @discover_pod other_pod_id

    if ENABLE_PERSISTENCE
      @podfile = new JSONFile "data/pods/know_pods:#{@pod.pod_id}.json"
      @podfile.load (error, obj) =>
        unless error is null
          logger.error error.message
          return
        for pod_id of obj.known_pods
          @discover_pod pod_id


    # TODO make it possible to stop polling
    POD_PING_INTERVAL = 3 * 1000
    pod_ping_interval_id = plantInterval POD_PING_INTERVAL, =>
      logger.debug "sending pod pings"
      for pod_id of @known_pods
        logger.debug "sending pod ping to #{pod_id}"
        @local_node.msg_pod pod_id, JSON.stringify
          type: 'pod_ping'
          sender: pod_id: @pod.pod_id
          others: @known_pods
    pod_ping_interval_id.unref()

    @_setup_app()
    @server = http.createServer @app

  attach_node: (@local_node) ->
    logger.debug "HTTPPodView attaching local node."

  listen: (@port, @host) ->
    unless typeof @port is 'number'
      throw new Error "Bad port #{@port}"

    @server.listen @port, @host, =>
      logger.debug "HTTPPodView listening on #{@host}:#{@port}"

  discover_pod: (pod_id) ->
    if pod_id is @pod.pod_id
      return

    # save pod
    @known_pods[pod_id] ?= null

    if ENABLE_PERSISTENCE
      save_data = known_pods: {}
      for pod_id of @known_pods
        save_data.known_pods[pod_id] = null
      @podfile.save save_data, (error) ->
        unless error is null
          logger.error error.message
          return

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

    @app.get '/known_pods', (req, res) =>
      template = handlebars.compile '''
        <h1>Pod Pings</h1>
        <table border="1">
          <tr>
            <td>sender</td>
            <td>date</td>
            <td>utc</td>
            <td>minutes since</td>
          </tr>
          {{#pings}}
            <tr>
              <td> {{sender_id}} </td>
              <td> {{date}} </td>
              <td> {{utc}} </td>
              <td> {{since}} </td>
            </tr>
          {{/pings}}
        </table>
      '''

      pings = []
      for sender_id, date of @known_pods
        pings.push
          sender_id: sender_id
          date: new Date date
          utc: date
          since: (((new Date).getTime() - date) / 1000 / 60).toFixed 2

      res.send template pings: pings

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

    @app.post '/api/discover_pod', (req, res) =>
      unless req.body.pod_id? and req.body?
        logger.debug "received invalid post request to /api/discover_pod"
        return res.send 400, "missing post parameters"

      logger.debug "discovering pod."
      @discover_pod req.body.pod_id.trim()
      res.send 200, "pod added."


module.exports =
  HTTPPodView: HTTPPodView
