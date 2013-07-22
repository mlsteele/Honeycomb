Pod = require '../src/pod'

describe 'pod', ->
  beforeEach ->
    @p = new Pod
  it 'has a .pod_id attribute', ->
    expect(@p.pod_id?).toBeDefined()

  it 'has a recv_msg method', ->
    spyOn @p, 'recv_msg'
    @p.recv_msg 'test message'
    expect(@p.recv_msg).toHaveBeenCalledWith 'test message'
