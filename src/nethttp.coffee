http = require 'http'
{LocalNode, ForeignNode} = require './netbase'

class HTTPLocalNode extends LocalNode
  # * `cb` is called after the server initializes.
  constructor: (@host, @port) ->
    super()

    @server = http.createServer (req, res) ->
      @_handle_request req, res

  listen: (cb) ->
    @server.listen @port, @host, cb

  _handle_request: (req, res) ->
    url = (url_parse req.url)

    if req.method is 'GET'
      if url.pathname is '/'
        res.writeHead 200, 'Content-Type': 'text/plain'
        return res.end "okay"

    else if req.method is 'POST'
      if url.pathname is '/msg_pod'
        res.writeHead 200, 'Content-Type': 'text/plain'
        return res.end "okay"

    # default 404
    res.writeHead 404, 'Content-Type': 'text/plain'
    return res.end "path not found"

# representation of an external node
class HTTPForeignNode extends ForeignNode
  constructor: (@host, @port) ->
    super()

  msg_pod: (pod_id, msg) ->
    options =
      hostname: @host
      port: @port
      path: "/msg_pod"
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
