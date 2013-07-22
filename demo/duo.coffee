Pod = require '../src/pod'
{HTTPLocalNode, HTTPForeignNode} = require '../src/nethttp'
{plantTimeout} = require '../src/helpers'
logger = require '../src/logger'

HOSTS = ['localhost', 'localhost']
PORTS = [8045, 8046]
pods = [new Pod, new Pod]

do ->
  ln = new HTTPLocalNode PORTS[0], HOSTS[0]
  logger.info "created http node on #{ln.host}:#{ln.port}"
  ln.add_pod pods[0]
  logger.info "added pod #{pods[0].pod_id}"

  fn = new HTTPForeignNode PORTS[1], HOSTS[1]
  ln.add_foreign_node fn
  plantTimeout 500, ->
    fn.update()

  ln.listen -> logger.info "http node listening on #{ln.host}:#{ln.port}"

do ->
  ln = new HTTPLocalNode PORTS[1], HOSTS[1]
  logger.info "created http node on #{ln.host}:#{ln.port}"
  ln.add_pod pods[1]
  logger.info "added pod #{pods[1].pod_id}"

  fn = new HTTPForeignNode PORTS[0], HOSTS[0]
  ln.add_foreign_node fn

  ln.listen -> logger.info "http node listening on #{ln.host}:#{ln.port}"
