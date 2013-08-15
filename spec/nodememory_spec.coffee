Pod = require '../src/pod'
{MemLocalNode, MemExtNode} = require '../src/nodememory'

beforeEach ->
  @addMatchers toHaveKey: (expected) ->
    @message = => "Expected #{@actual} to have key #{expected}"
    expected of @actual

describe "MemLocalNode", ->
  beforeEach ->
    @ln = new MemLocalNode
    @pod = new Pod

  it "has a node_id.", ->
    expect(@ln).toHaveKey 'node_id'

  it "adds a local pod.", ->
    @ln.add_pod @pod
    expect(@ln.pods).toHaveKey @pod.pod_id

  it "adds a external node", ->
    @ext_ln = new MemLocalNode
    @en = new MemExtNode @ext_ln
    @ln.add_ext_node @en
    expect(@ln.ext_nodes).toHaveKey @en.node_id
    expect(@ln.ext_nodes[@en.node_id]).toBe @en

  it "messages a local pod.", ->
    spyOn @pod, 'recv_msg'
    @ln.add_pod @pod
    @ln.msg_pod @pod.pod_id, 'test message 1'
    expect(@pod.recv_msg).toHaveBeenCalledWith 'test message 1'

describe "MemExtNode", ->
  beforeEach ->
    @ln = new MemLocalNode
    @pod = new Pod
    @ln.add_pod @pod

  it "is created with a MemLocalNode.", ->
    en = new MemExtNode @ln
    expect(en.ext_local_node).toBe @ln

  it "tells the local node to message its pod.", ->
    spyOn @ln, 'msg_pod'
    en = new MemExtNode @ln
    en.msg_pod @pod.pod_id, 'test message 2'
    expect(@ln.msg_pod).toHaveBeenCalledWith @pod.pod_id, 'test message 2'

  it "messages a MemLocalNode's pod.", ->
    spyOn @pod, 'recv_msg'
    en = new MemExtNode @ln
    en.msg_pod @pod.pod_id, 'test message 2'
    expect(@pod.recv_msg).toHaveBeenCalledWith 'test message 2'

  it "updates pods_relation.", ->
    en = new MemExtNode @ln
    en.update()
    expect(en.pods_relations).toHaveKey @pod.pod_id
    relation = en.pods_relations[@pod.pod_id]
    expect(relation).toEqual
      type: 'mem'
      hops: 0

describe "Memory nodes", ->
  it "send a message to an external pod.", ->
    @pod = new Pod
    spyOn @pod, 'recv_msg'

    @ext_ln = new MemLocalNode
    @ext_ln.add_pod @pod
    @en = new MemExtNode @ext_ln
    spyOn(@en, 'msg_pod').andCallThrough()
    @ln = new MemLocalNode
    @ln.add_ext_node @en
    @en.update()
    @ln.msg_pod @pod.pod_id, 'test message 3'
    expect(@en.msg_pod).toHaveBeenCalledWith @pod.pod_id, 'test message 3'
    expect(@pod.recv_msg).toHaveBeenCalledWith 'test message 3'
