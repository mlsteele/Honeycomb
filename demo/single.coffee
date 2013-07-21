Pod = require '../src/pod'
{HTTPLocalNode} = require './src/nethttp'

ln = new HTTPLocalNode 8049, 'localhost'
local_pod = new Pod
console.log local_pod.pod_id
ln.add_pod local_pod

ln.msg_pod local_pod.pod_id, 'initial test message'
ln.listen()
