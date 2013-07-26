http = require 'http'
request = require 'request'
Pod = require '../src/pod'
{HTTPLocalNode, HTTPForeignNode} = require '../src/nethttp'

TESTING_PORT = 8087

describe 'HTTPLocalNode', ->

  it 'inherits the ability to hold local pods', ->
    @ln = new HTTPLocalNode TESTING_PORT, 'localhost'
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
      @ln = new HTTPLocalNode TESTING_PORT, 'localhost'
      @ln.listen @callback

    waitsFor => wait_for_this

    runs => expect(@callback).toHaveBeenCalled()

  describe 'listens over http', ->
    beforeEach ->
      @port = TESTING_PORT
      @ln = new HTTPLocalNode @port, 'localhost'
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
            hostname: 'localhost'
            port: @port
            path: '/check'
            method: 'GET'

          req.end()

      waitsFor => latch

      runs => @ln.server.close()

    it 'and receives a request to send messages to pods', ->
      latch = false

      spyOn @ln, 'msg_pod'

      runs =>
        @ln.server.on 'request', (req, res) =>
          expect(req.url).toEqual "/msg_pod/#{@pod.pod_id}"
          console.log req.url

        @ln.listen =>
          request.post "http://localhost:#{@port}/msg_pod/#{@pod.pod_id}",
            form: msg: 'test message',
            (error, res, body) =>
              if error isnt null then @fail()
              if res.statusCode isnt 200
                console.log res.statusCode
                console.log body
                @fail()
              latch = true

      waitsFor => latch

      runs =>
        @ln.server.close()
        expect(@ln.msg_pod).toHaveBeenCalledWith @pod.pod_id, 'test message'


describe 'HTTPForeignNode', ->
  it 'asks what pods it knows about.', ->
    ln = new HTTPLocalNode TESTING_PORT, 'localhost'
    pod = new Pod
    ln.add_pod pod
    fn = new HTTPForeignNode 'localhost', TESTING_PORT

    latch = false
    runs => ln.listen => fn.update (error) =>
      expect(error).toBeNull()
      latch = true
    waitsFor => latch
    runs =>
      ln.server.close()
      expect(fn.pods_info).toBeDefined()
      expect(fn.pods_info[pod.pod_id]).toBeDefined()

      expected = {}
      expected[pod.pod_id] = type: 'local'
      expect(fn.pods_info).toEqual expected

  it 'can tell the target to msg a pod.', ->
    ln = new HTTPLocalNode TESTING_PORT, 'localhost'
    fn = new HTTPForeignNode 'localhost', TESTING_PORT
    pod = new Pod
    ln.add_pod pod
    fn.pods_info[pod.pod_id] = local: true

    spyOn ln, 'msg_pod'

    latch = false

    runs => ln.listen =>
      fn.msg_pod pod.pod_id, 'test message'
      # TODO race condition?
      latch = true

    waitsFor => latch

    runs =>
      ln.server.close()
      expect(ln.msg_pod).toHaveBeenCalledWith pod.pod_id, 'test message'
