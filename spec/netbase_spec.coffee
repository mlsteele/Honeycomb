Pod = require '../src/pod'
{LocalNode, ForeignNode, LocalForeignNode} = require '../src/netbase'

describe 'LocalNode', ->
  beforeEach ->
    @ln = new LocalNode

  it 'holds local pods', ->
    expect(@ln.pods.length).toEqual 0
    pod = new Pod
    @ln.add_pod pod
    expect(@ln.pods).toContain pod

  it 'can send messages to local pods', ->
    pod = new Pod
    spyOn pod, 'recv_msg'
    @ln.add_pod pod
    @ln.msg_pod pod.pod_id, 'test_message'
    expect(pod.recv_msg).toHaveBeenCalledWith 'test_message'

  it 'knows about foreign nodes', ->
    expect(@ln.pods.length).toEqual 0
    fn = new ForeignNode
    @ln.add_foreign_node fn
    expect(@ln.foreign_nodes).toContain fn

  it 'can tell a foreign node to message a foreign pod', ->
    fn = new ForeignNode
    @ln.add_foreign_node fn
    foreign_pod = new Pod
    fn.pods_info[foreign_pod.pod_id] = dummy: true
    spyOn fn, 'msg_pod'
    @ln.msg_pod foreign_pod.pod_id, 'test_message'
    expect(fn.msg_pod).toHaveBeenCalledWith foreign_pod.pod_id, 'test_message'
