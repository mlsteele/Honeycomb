Pod = require '../src/pod'
{HTTPLocalNode, HTTPForeignNode} = require '../src/nethttp'

HOSTS = ['localhost', 'localhost']
PORTS = [8045, 8046]
pods = [new Pod, new Pod]

do ->
  ln = new HTTPLocalNode PORTS[0], HOSTS[0]
  console.log "created http node on #{ln.host}:#{ln.port}"
  ln.add_pod pods[0]
  console.log "added pod #{pods[0].pod_id}"

  fn = new HTTPForeignNode PORTS[1], HOSTS[1]
  ln.add_foreign_node fn

  ln.listen ->
    console.log "http node listening on #{ln.host}:#{ln.port}"
    fn.add_pod_id pods[1].pod_id

do ->
  ln = new HTTPLocalNode PORTS[1], HOSTS[1]
  console.log "created http node on #{ln.host}:#{ln.port}"
  ln.add_pod pods[1]
  console.log "added pod #{pods[1].pod_id}"

  fn = new HTTPForeignNode PORTS[0], HOSTS[0]
  ln.add_foreign_node fn

  ln.listen ->
    console.log "http node listening on #{ln.host}:#{ln.port}"
    fn.add_pod_id pods[0].pod_id
