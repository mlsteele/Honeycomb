module.exports =
  # Reverse argument order to be more coffeescript-amenable.
  plantTimeout: (ms, cb) -> setTimeout cb, ms
  plantInterval: (ms, cb) -> setInterval cb, ms

  # Parse a hostname of the form "0.0.0.0:1234".
  # Port is required for a match.
  # Returns object of the form {host: "0.0.0.0", port: 1234}.
  # Returns undefined if the parse fails.
  parseHost: (host_str) ->
    host_regex = /(.+):(\d+)/
    match = host_str.match host_regex
    if match?
      [_, host, port_str] = match
      port = parseInt port_str
      if port is NaN
        return undefined
      return {host: host, port: port}
    else
      return undefined
