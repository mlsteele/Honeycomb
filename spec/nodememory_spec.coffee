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

    lns = [new MemLocalNode, new MemLocalNode]
    ens = (new MemExtNode ln for ln in lns)

    lns[1].add_pod @pod
    spyOn(ens[1], 'msg_pod').andCallThrough()
    lns[0].add_ext_node ens[1]

    ens.map (en) -> en.update()
    lns[0].msg_pod @pod.pod_id, 'test message 3'

    expect(ens[1].msg_pod).toHaveBeenCalledWith @pod.pod_id, 'test message 3'
    expect(@pod.recv_msg).toHaveBeenCalledWith 'test message 3'

  it "can pass messages over a hop.", ->
    @pod = new Pod
    spyOn @pod, 'recv_msg'

    lns = [new MemLocalNode, new MemLocalNode, new MemLocalNode]
    ens = (new MemExtNode ln for ln in lns)

    lns[0].add_ext_node ens[1]
    lns[1].add_ext_node ens[2]
    lns[2].add_pod @pod

    # update twice so that the information can propogate far enough
    ens.map (en) -> en.update()
    ens.map (en) -> en.update()
    lns[0].msg_pod @pod.pod_id, 'test message 4'

    expect(@pod.recv_msg).toHaveBeenCalledWith 'test message 4'

  it "can pass messages over two hops.", ->
    @pod = new Pod
    spyOn @pod, 'recv_msg'

    lns = [new MemLocalNode, new MemLocalNode, new MemLocalNode, new MemLocalNode]
    ens = (new MemExtNode ln for ln in lns)

    lns[0].add_ext_node ens[1]
    lns[1].add_ext_node ens[2]
    lns[2].add_ext_node ens[3]
    lns[3].add_pod @pod

    # update enough that the information can propogate
    ens.map (en) -> en.update()
    ens.map (en) -> en.update()
    ens.map (en) -> en.update()
    lns[0].msg_pod @pod.pod_id, 'test message 4'

    expect(@pod.recv_msg).toHaveBeenCalledWith 'test message 4'

  it "do not duplicate ext node representations.", ->
    @pod = new Pod
    spyOn @pod, 'recv_msg'

    lns = [new MemLocalNode, new MemLocalNode, new MemLocalNode]
    ens = (new MemExtNode ln for ln in lns)

    lns[0].add_ext_node ens[1]
    lns[1].add_ext_node ens[0]
    lns[1].add_ext_node ens[2]
    lns[2].add_ext_node ens[1]
    lns[2].add_pod @pod

    ens.map (en) -> en.update()
    ens.map (en) -> en.update()
    ens.map (en) -> en.update()
    ens.map (en) -> en.update()
    ens.map (en) -> en.update()
    ens.map (en) -> en.update()

    expect(ens[0].pods_relations[@pod.pod_id].hops).toBe 2
    expect(ens[1].pods_relations[@pod.pod_id].hops).toBe 1
    expect(ens[2].pods_relations[@pod.pod_id].hops).toBe 0
