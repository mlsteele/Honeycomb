Pod = require '../src/pod'
{TCPLocalNode, TCPExtNode} = require '../src/nodetcp'

TESTING_PORTS = [8933]

beforeEach ->
  @addMatchers toHaveKey: (expected) ->
    @message = => "Expected #{@actual} to have key #{expected}"
    expected of @actual

describe "TCPLocalNode", ->
  beforeEach ->
    @ln = new TCPLocalNode port: TESTING_PORTS[0]
    @pod = new Pod

  it "has a node_id.", ->
    expect(@ln).toHaveKey 'node_id'

  it "has a a hostname and port.", ->
    expect(@ln).toHaveKey 'hostname'
    expect(@ln).toHaveKey 'port'

  it "adds a local pod.", ->
    @ln.add_pod @pod
    expect(@ln.pods).toHaveKey @pod.pod_id

  it "adds a external node", ->
    @ext_ln = new TCPLocalNode port: TESTING_PORTS[0]
    @en = new TCPExtNode hostname: 'localhost', port: TESTING_PORTS[0]
    @ln.add_ext_node @en
    expect(@ln.ext_nodes).toHaveKey @en.node_id
    expect(@ln.ext_nodes[@en.node_id]).toBe @en

  it "messages a local pod.", ->
    spyOn @pod, 'recv_msg'
    @ln.add_pod @pod
    @ln.msg_pod @pod.pod_id, 'test message 1'
    expect(@pod.recv_msg).toHaveBeenCalledWith 'test message 1'

describe "TCPExtNode", ->
  beforeEach ->
    @ln = new TCPLocalNode port: TESTING_PORTS[0]
    @pod = new Pod
    @ln.add_pod @pod

  it "is created with a hostname and port.", ->
    en = new TCPExtNode hostname: 'localhost', port: TESTING_PORTS[0]
    expect(en.hostname).toBe 'localhost'
    expect(en.port).toBe TESTING_PORTS[0]

  it "tells the external node to message its pod.", ->
    spyOn @ln, 'msg_pod'
    en = new TCPExtNode hostname: 'localhost', port: TESTING_PORTS[0]

    latch = false

    runs => @ln.listen()
    waitsFor 500, => @ln.is_listening()
    runs => en.connect()
    waitsFor 500, => en.is_connected()
    runs => en.update => latch = true
    waitsFor => latch
    runs => en.msg_pod @pod.pod_id, 'test message 2'
    waitsFor =>
    runs => expect(@ln.msg_pod).toHaveBeenCalledWith @pod.pod_id, 'test message 2'

  xit "messages a TCPLocalNode's pod.", ->
    spyOn @pod, 'recv_msg'
    en = new TCPExtNode hostname: 'localhost', port: TESTING_PORTS[0]
    en.msg_pod @pod.pod_id, 'test message 2'
    expect(@pod.recv_msg).toHaveBeenCalledWith 'test message 2'

  xit "updates pods_relation.", ->
    en = new TCPExtNode hostname: 'localhost', port: TESTING_PORTS[0]
    en.update()
    expect(en.pods_relations).toHaveKey @pod.pod_id
    relation = en.pods_relations[@pod.pod_id]
    expect(relation).toEqual
      type: 'TCP'
      hops: 0

# xdescribe "TCP nodes", ->
#   it "send a message to an external pod.", ->
#     @pod = new Pod
#     spyOn @pod, 'recv_msg'

#     lns = [new TCPLocalNode, new TCPLocalNode port: TESTING_PORTS[0]]
#     ens = (new TCPExtNode ln for ln in hostname: 'localhost', port: TESTING_PORTS[0])

#     lns[1].add_pod @pod
#     spyOn(ens[1], 'msg_pod').andCallThrough()
#     lns[0].add_ext_node ens[1]

#     ens.map (en) -> en.update()
#     lns[0].msg_pod @pod.pod_id, 'test message 3'

#     expect(ens[1].msg_pod).toHaveBeenCalledWith @pod.pod_id, 'test message 3'
#     expect(@pod.recv_msg).toHaveBeenCalledWith 'test message 3'

#   it "can pass messages over a hop.", ->
#     @pod = new Pod
#     spyOn @pod, 'recv_msg'

#     lns = [new TCPLocalNode port: p for p in TESTING_PORTS]
#     ens = (new TCPExtNode ln for ln in hostname: 'localhost', port: TESTING_PORTS[0])

#     lns[0].add_ext_node ens[1]
#     lns[1].add_ext_node ens[2]
#     lns[2].add_pod @pod

#     # update twice so that the information can propogate far enough
#     ens.map (en) -> en.update()
#     ens.map (en) -> en.update()
#     lns[0].msg_pod @pod.pod_id, 'test message 4'

#     expect(@pod.recv_msg).toHaveBeenCalledWith 'test message 4'

#   it "can pass messages over two hops.", ->
#     @pod = new Pod
#     spyOn @pod, 'recv_msg'

#     lns = [new TCPLocalNode port: p for p in TESTING_PORTS]
#     ens = (new TCPExtNode ln for ln in hostname: 'localhost', port: TESTING_PORTS[0]

#     lns[0].add_ext_node ens[1]
#     lns[1].add_ext_node ens[2]
#     lns[2].add_ext_node ens[3]
#     lns[3].add_pod @pod

#     # update enough that the information can propogate
#     ens.map (en) -> en.update()
#     ens.map (en) -> en.update()
#     ens.map (en) -> en.update()
#     lns[0].msg_pod @pod.pod_id, 'test message 4'

#     expect(@pod.recv_msg).toHaveBeenCalledWith 'test message 4'

#   it "do not duplicate ext node representations.", ->
#     @pod = new Pod
#     spyOn @pod, 'recv_msg'

#     lns = [new TCPLocalNode, new TCPLocalNode, new TCPLocalNode] port: TESTING_PORTS[0]
#     ens = (new TCPExtNode ln for ln in hostname: 'localhost', port: TESTING_PORTS[0]

#     lns[0].add_ext_node ens[1]
#     lns[1].add_ext_node ens[0]
#     lns[1].add_ext_node ens[2]
#     lns[2].add_ext_node ens[1]
#     lns[2].add_pod @pod

#     ens.map (en) -> en.update()
#     ens.map (en) -> en.update()
#     ens.map (en) -> en.update()
#     ens.map (en) -> en.update()
#     ens.map (en) -> en.update()
#     ens.map (en) -> en.update()

#     expect(ens[0].pods_relations[@pod.pod_id].hops).toBe 2
#     expect(ens[1].pods_relations[@pod.pod_id].hops).toBe 1
#     expect(ens[2].pods_relations[@pod.pod_id].hops).toBe 0
