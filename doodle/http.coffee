http = require 'http'
url_parse = require 'url'

HOST = 'localhost'
PORT_TOWN = 8977

server = http.createServer (req, res) ->
  res.writeHead 200, 'Content-Type': 'text/plain'
  res.end "okay"

server.on 'request', (req, res) ->
  console.log "\n\nREQ\n"
  console.log req
  console.log "\n\nRES\n"
  console.log res
  console.log "method #{req.method}"
  console.log 'OOOH-BABY--OOH-OOH-BABY-BABY... OOH'

server.listen PORT_TOWN, HOST, ->
  console.log 'server listening'

  req = http.request
    host: HOST
    port: PORT_TOWN
    (res) ->
      console.log 'foobar response'
      console.log res.statusCode
      server.close()

  # req.write 'foo'
  req.end()
