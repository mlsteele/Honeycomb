plantTimeout = (ms, cb) -> setTimeout cb, ms
uuid = require 'node-uuid'
http = require 'http'

class Pod
  constructor: (@pod_id) ->

  recv_msg: (msg) ->
    console.log "pod #{@pod_id} received message '#{msg}'"


class LocalNode
  constructor: ->
    @pods = []
    # list of ForeignNode's
    @foreign_nodes = []

  add_pod: (pod) ->
    @pods.push pod

  add_foreign_node: (node) ->
    @foreign_nodes.push node

  # send a message to the pod.
  # returns false if the pod could not be found.
  msg_pod: (pod_id, msg) ->
    # mock asynchronous callout
    plantTimeout 100, =>
      # search in this node
      local_pod = (p for p in @pods when p.pod_id is pod_id)[0]
      if local_pod
        console.log "found in local"
        return local_pod.recv_msg msg

      # search in friend nodes
      for foreign_node in @foreign_nodes
        foreign_pod_id = (fp_id for fp_id in foreign_node.pod_ids when fp_id is pod_id)[0]
        if foreign_pod_id
          console.log "found in foreign"
          return foreign_node.msg_pod foreign_pod_id, msg

      console.warn "could not pass message."


class HTTPLocalNode extends LocalNode
  constructor: (@host, @port) ->
    @server = http.createServer (req, res) ->
      res.writeHead 200, 'Content-Type': 'text/plain'
      res.end "okay"
    @server.listen @port, @host


# representation of an external node
class ForeignNode
  constructor: ->
    @pod_ids = []

  msg_pod: (pod_id, msg) ->
    throw "not implemented"

  add_pod_id: (pod_id) ->
    @pod_ids.push pod_id

  fetch_pod_ids: ->
    throw "not implemented"


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


# local foreign node
# for mocking an external node from a LocalNode
class LocalForeignNode extends ForeignNode
  constructor: (@local_node) ->
    super()

  msg_pod: (pod_id, msg) ->
    @local_node.msg_pod pod_id, msg

  add_local_pod_ids: ->
    (@add_pod_id p.pod_id) for p in @local_node.pods



which_thing = 'http'

if which_thing is 'local'
  some_pod = new Pod uuid.v4()
  console.log "some_pod pod_id: #{some_pod.pod_id}"
  local_node = new LocalNode()
  local_node.add_pod some_pod

  other_pod = new Pod uuid.v4()
  console.log "other_pod pod_id: #{other_pod.pod_id}"
  other_node = new LocalNode()
  other_node.add_pod other_pod

  foreign_node = new LocalForeignNode other_node
  foreign_node.add_local_pod_ids()

  local_node.add_foreign_node foreign_node
  local_node.msg_pod some_pod.pod_id, 'hello local.'
  local_node.msg_pod other_pod.pod_id, 'hello other.'
else if which_thing is 'http'
  some_pod = new Pod uuid.v4()
  console.log "some_pod pod_id: #{some_pod.pod_id}"
  local_node = new HTTPLocalNode 'localhost', 8417
  # local_node.add_pod some_pod

  # foreign_node = new HTTPForeignNode other_node
  # foreign_node.add_local_pod_ids()

  # local_node.add_foreign_node foreign_node
  local_node.msg_pod some_pod.pod_id, 'hello local.'
  # local_node.msg_pod other_pod.pod_id, 'hello other.'
