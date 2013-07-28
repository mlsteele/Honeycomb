Pod = require '../src/pod'
{HTTPLocalNode, HTTPForeignNode} = require '../src/nethttp'
{HTTPPodView} = require '../src/podview'

# A is the hub.

POD_PORTS =
  a: 7301
  b: 7302
  c: 7303
  d: 7304
# TODO remove hacked pod id persistences
POD_IDS =
  a: 'pod:1265e0e1-c5ed-4dd3-a568-2e65f960d7bd'
  b: 'pod:073b7d26-5148-453a-8a09-98bcf641fdd1'
  c: 'pod:28bf2864-ebf4-46d7-b4e6-afb88987fec3'
  d: 'pod:24ee79db-af9a-4048-9048-d2de167264e1'
PORTS =
  a: 7201
  b: 7202
  c: 7203
  d: 7204

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

# create local noe
ln = new HTTPLocalNode PORTS[which], 'localhost'

# create pod
pod = new Pod
# HACK
pod.pod_id = POD_IDS[which]
podview = new HTTPPodView pod
podview.listen POD_PORTS[which], 'localhost'
podview.attach_node ln

ln.add_pod pod
ln.listen ->
  # initial knowledge of hug at A
  unless which is 'a'
    ln.discover_node 'localhost', PORTS['a'], yes
