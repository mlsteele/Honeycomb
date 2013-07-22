{parseHost} = require '../src/helpers'

describe 'parseHost', ->
  it 'behaves as expected', ->
    expect(parseHost "localhost:1234").toEqual {host: "localhost", port: 1234}
    expect(parseHost "127.9.9.1:613").toEqual {host: "127.9.9.1", port: 613}

    expect(parseHost "localhost:").toEqual undefined
    expect(parseHost "localhost").toEqual undefined
    expect(parseHost "foobar1234").toEqual undefined
    expect(parseHost ":foobar1234").toEqual undefined
    expect(parseHost "fooba::r1234").toEqual undefined
