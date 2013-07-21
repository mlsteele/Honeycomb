Pod = require '../src/pod'
{HTTPLocalNode, HTTPForeignNode} = require '../src/nethttp'
{HTTPPodView} = require '../src/podview'

pod = new Pod
podview = new HTTPPodView pod
podview.listen 7441

ln = new HTTPLocalNode 7551
ln.add_pod pod
ln.listen()
