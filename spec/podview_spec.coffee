Pod = require '../src/pod'
{HTTPPodView} = require '../src/podview'

describe 'HTTPPodView', ->
  beforeEach ->
    @pod = new Pod
    @pv = new HTTPPodView @pod

  it 'know which pod it is a view on', ->
    expect(@pv.pod).toBe @pod

  it 'stores messages', ->
    @pod.recv_msg 'foo'
    @pod.recv_msg 'bar'
    @pod.recv_msg 'baz'
    expect(@pv.messages).toEqual ['foo', 'bar', 'baz']
