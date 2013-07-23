Pod = require '../src/pod'
{HTTPLocalNode, HTTPForeignNode} = require '../src/nethttp'
{HTTPPodView} = require '../src/podview'

# A has the pod.
# B is the hub.

POD_PORT = 7441
PORTS =
  a: 7443
  b: 7445
  c: 7446
  d: 7447

which = process.argv[2]

unless which in ['a', 'b', 'c', 'd']
  console.log """
    Usage:
    a - run node A (with view)
    b - run node B
    c - run node C
    d - run node D
  """
  process.exit(0)

pod = new Pod
if which is 'a'
  podview = new HTTPPodView pod
  podview.listen POD_PORT, 'localhost'
  podview.attach_node ln

ln = new HTTPLocalNode PORTS[which], 'localhost'
ln.add_pod pod
ln.listen ->

unless which is 'b'
  b_node = new HTTPForeignNode 'localhost', PORTS['b']
  ln.add_foreign_node b_node
  b_node.update()
  b_node.publish ln
