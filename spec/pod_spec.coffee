Pod = require '../src/pod'

describe 'pod', ->
  beforeEach ->
    @p = new Pod
  it 'has a .pod_id attribute', ->
    expect(@p.pod_id?).toBeDefined()

  it 'prints received messages', ->
    spyOn console, 'log'
    @p.recv_msg 'test_message'
    expect(console.log).toHaveBeenCalled()
