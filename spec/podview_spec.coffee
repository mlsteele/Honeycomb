Pod = require '../src/pod'
{HTTPPodView} = require '../src/podview'

describe 'HTTPPodView', ->
  it 'know which pod it is a view on', ->
    p = new Pod
    pv = new HTTPPodView p
    expect(pv.pod).toBe p
