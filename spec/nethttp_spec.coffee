http = require 'http'
Pod = require '../src/pod'
{HTTPLocalNode, HTTPForeignNode} = require '../src/nethttp'

describe 'HTTPLocalNode', ->
  it 'inherits the ability to hold local pods', ->
    @ln = new HTTPLocalNode 'localhost', 8049
    expect(@ln.pods.length).toEqual 0
    pod = new Pod
    @ln.add_pod pod
    expect(@ln.pods).toContain pod

  it 'initializes a server and calls callback', ->
    wait_for_this = false
    @callback = =>
      @ln.server.close()
      wait_for_this = true
    spyOn(@, 'callback').andCallThrough()

    runs =>
      @ln = new HTTPLocalNode 'localhost', 8049
      @ln.listen @callback

    waitsFor => wait_for_this

    runs => expect(@callback).toHaveBeenCalled()

  describe 'listens over http', ->
    beforeEach ->
      @port = 8049
      @ln = new HTTPLocalNode 'localhost', @port
      @pod = new Pod
      @ln.add_pod @pod
      expect(@ln.pods).toContain @pod

    it 'and receives requests', ->
      latch = false

      runs =>
        @ln.server.on 'request', (req, res) =>
          latch = true

        @ln.listen =>
          req = http.request
            host: 'localhost'
            port: @port
            path: '/check'
            method: 'GET'

          req.end()

      waitsFor => latch

      runs => @ln.server.close()

    it 'and receives a requests to send messages to pods', ->
      latch = false

      spyOn @ln, 'msg_pod'

      runs =>
        @ln.server.on 'request', (req, res) =>
          latch = true

        @ln.listen =>
          req = http.request
            host: 'localhost'
            port: @port
            path: "/msg_pod/#{@pod.pod_id}"
            method: 'POST'

          req.end 'test message'

      waitsFor => latch

      runs =>
        @ln.server.close()
        expect(@ln.msg_pod).toHaveBeenCalledWith @pod.pod_id, 'test message'
