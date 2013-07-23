Pod = require '../src/pod'
{LocalNode, ForeignNode, LocalForeignNode} = require '../src/netbase'

describe 'LocalNode', ->
  class DummyNode extends ForeignNode
    constructor: -> super()
    msg_pod: ->

  beforeEach ->
    @addMatchers toHaveKey: (expected) ->
      @message = => "Expected #{@actual} to have key #{expected}"
      expected of @actual

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
    fn = new DummyNode
    @ln.add_foreign_node fn
    expect(@ln.foreign_nodes).toHaveKey fn.node_id
    expect(@ln.foreign_nodes[fn.node_id]).toBe fn

  it 'can tell a foreign node to message a foreign pod', ->
    fail = @fail

    # extend LocalNode to look for the first foreign node which has
    # the node with a 'local' type.
    class LocalSeeker extends LocalNode
      msg_pod: (pod_id, msg) ->
        expect(pod_id).toEqual foreign_pod.pod_id
        expect(msg).toEqual 'test_message'
        expect(super pod_id, msg).toBe false

        # search in foreign nodes for dummies
        for fn_id, fn of @foreign_nodes
          for pod_id, pod_info of fn.pods_info
            if pod_info.type is 'local'
              # only try the first match
              return fn.msg_pod pod_id, msg

        fail()

    fn = new DummyNode
    spyOn fn, 'msg_pod'
    foreign_pod = new Pod
    fn.pods_info[foreign_pod.pod_id] = type: 'local'

    @ln = new LocalSeeker
    @ln.add_foreign_node fn
    @ln.msg_pod foreign_pod.pod_id, 'test_message'
    expect(fn.msg_pod).toHaveBeenCalledWith foreign_pod.pod_id, 'test_message'
