Slot.js
=======
`npm install callback-slot`

## Description - What is a slot?

Slot.js is an attempt to ease the pain of callback management.

A slot is a callback 'channel'. It is a programmatic venue which is
asychronous, but where the expected behavior becomes outdated quickly. A slot
is responsible for firing only the latest registered callback in that slot. A
slot will not fire any old callbacks other than the latest registered
callback. I wrote this thing and that still doesn't make any sense, so let's look
at an example instead.

## Usage

    slot = make_slot()

    # This is an example callback
    callback = (data) -> console.log(data)
    # Usually callbacks will involve rendering to a view
    # and checking for errors.

    # Slots return the original callback.
    # So in the simplest case this
    callback "foobar"
    # is equivalent to this
    (slot callback) "foobar"

    # Let's register a callback for asynchronous data.
    # Assume async_fetcher takes 2 arguments: `url` and `callback`.
    async_fetcher 'http://data.please/foobar', slot (data) ->
      render data

    # After we register this next callback, we can rest assured that the
    # callback for data from /foobar will NOT be called after the callback for
    # data from /foobaz because they were registered to the same slot and
    # /foobaz was registered latest.
    async_fetcher 'http://data.please/foobaz', slot (data) ->
      render data
    # If /foobar were to return after /foobaz,
    # the /foobar callback would be ignored.

    # Slots are automatically cleared when they are called with a new callback.
    # To explicitly clear a slot so that no old callbacks fire.
    slot.clear()

## Installation
### Node.js

Install with node's npm package manager.

    $ npm install callback-slot
    $ node
    > make_slot = require('callback-slot')
    > some_slot = make_slot()

### Browser
Slots were originally intended for browser development. The `src/slot.coffee` file uses

    module.exports = make_slot

for convenience during testing. To use slots in the browser, replace that line
with whatever import system you are using, or copy the function into your
helpers file.
