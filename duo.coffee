Pod = require './src/pod'
{HTTPLocalNode, HTTPForeignNode} = require './src/nethttp'

HOSTS = ['localhost', 'localhost']
PORTS = [8045, 8046]
pods = [new Pod, new Pod]

do ->
  ln = new HTTPLocalNode HOSTS[0], PORTS[0]
  console.log "created http node on #{ln.host}:#{ln.port}"
  ln.add_pod pods[0]
  console.log "added pod #{pods[0].pod_id}"

  fn = new HTTPForeignNode HOSTS[1], PORTS[1]
  ln.add_foreign_node fn

  ln.listen ->
    console.log "http node listening on #{ln.host}:#{ln.port}"
    fn.add_pod_id pods[1].pod_id

do ->
  ln = new HTTPLocalNode HOSTS[1], PORTS[1]
  console.log "created http node on #{ln.host}:#{ln.port}"
  ln.add_pod pods[1]
  console.log "added pod #{pods[1].pod_id}"

  fn = new HTTPForeignNode HOSTS[0], PORTS[0]
  ln.add_foreign_node fn

  ln.listen ->
    console.log "http node listening on #{ln.host}:#{ln.port}"
    fn.add_pod_id pods[0].pod_id
