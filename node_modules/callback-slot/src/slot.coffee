# make_slot() creates a slot for managing callbacks.
# The slot will only allow the last registered callback to fire.
make_slot = ->
  # latest_unique is an object which will be unique for every callback. This
  # is used instead of storing the callback because the same callback could be
  # passed twice to the slot, and it should not be fired twice. In javascript,
  # all objects are not equal when compared with === or 'is'.
  latest_unique = {}

  # callback is the 'setter' or 'renderer' function
  # to be locked into the slot.
  slot = (callback) ->
    callback_unique = {}
    latest_unique = callback_unique
    ->
      if callback_unique is latest_unique
        callback.apply this, arguments

  # clear the slot by registering a blank function
  slot.clear = -> slot ->

  return slot


module.exports = make_slot
