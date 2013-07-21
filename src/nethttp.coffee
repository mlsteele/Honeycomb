http = require 'http'
url_parse = (require 'url').parse
{LocalNode, ForeignNode} = require './netbase'

class HTTPLocalNode extends LocalNode
  # * `cb` is called after the server initializes.
  constructor: (@host, @port) ->
    super()

    @server = http.createServer (req, res) =>
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
      msg_pod_regex = /^\/msg_pod\/(.+)/
      target_pod_id = (url.pathname.match msg_pod_regex)?[1]
      if target_pod_id
        full_body = ""
        req.on 'data', (chunk) =>
          full_body += chunk.toString()
        req.on 'end', =>
          @msg_pod target_pod_id, full_body
          res.writeHead 200, 'Content-Type': 'text/plain'
          res.end "message sent."
        return


    # default 500
    res.writeHead 500, 'Content-Type': 'text/plain'
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
