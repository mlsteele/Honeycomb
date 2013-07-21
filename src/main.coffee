which_thing = 'http'

if which_thing is 'local'
  some_pod = new Pod uuid.v4()
  console.log "some_pod pod_id: #{some_pod.pod_id}"
  local_node = new LocalNode()
  local_node.add_pod some_pod

  other_pod = new Pod uuid.v4()
  console.log "other_pod pod_id: #{other_pod.pod_id}"
  other_node = new LocalNode()
  other_node.add_pod other_pod

  foreign_node = new LocalForeignNode other_node
  foreign_node.add_local_pod_ids()

  local_node.add_foreign_node foreign_node
  local_node.msg_pod some_pod.pod_id, 'hello local.'
  local_node.msg_pod other_pod.pod_id, 'hello other.'
else if which_thing is 'http'
  some_pod = new Pod uuid.v4()
  console.log "some_pod pod_id: #{some_pod.pod_id}"
  local_node = new HTTPLocalNode 'localhost', 8417
  # local_node.add_pod some_pod

  # foreign_node = new HTTPForeignNode other_node
  # foreign_node.add_local_pod_ids()

  # local_node.add_foreign_node foreign_node
  local_node.msg_pod some_pod.pod_id, 'hello local.'
  # local_node.msg_pod other_pod.pod_id, 'hello other.'
