Pod = require '../src/pod'
{HTTPLocalNode, HTTPForeignNode} = require '../src/nethttp'
{HTTPPodView} = require '../src/podview'

pod = new Pod
podview = new HTTPPodView pod
podview.listen 7441

ln = new HTTPLocalNode 7551, 'localhost'
ln.add_pod pod
podview.attach_node ln
ln.listen()
ln.listen_repl 7552, 'localhost'
