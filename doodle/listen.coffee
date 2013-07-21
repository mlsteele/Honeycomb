http = require 'http'

server = http.createServer (req, res) ->
  console.log 'go a request!'
  res.writeHead 200
  res.end "hello world\n"

server.listen 9929, 'localhost', ->
  console.log 'listening...'
