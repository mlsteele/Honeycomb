http = require 'http'
express = require 'express'

class HTTPPodView
  constructor: (@pod) ->
    @_setup_app()
    @server = http.createServer @app

  listen: (@port, @host) ->
    unless typeof @port is 'number'
      throw new Error "Bad port #{@port}"

    @server.listen @port, @host

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
      if @pod.messages.length
        html += "Here are your messages:"
      else
        html += "You have no messages. :("
      html += "<br>"
      for msg in @pod.messages
        html += "<p>#{msg}</p>"
      res.send html


module.exports =
  HTTPPodView: HTTPPodView
