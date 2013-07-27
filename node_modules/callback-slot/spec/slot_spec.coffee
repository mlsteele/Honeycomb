make_slot = require '../src/slot'
plantTimeout = (ms, cb) -> setTimeout cb, ms


describe 'make_slot()', ->
  describe 'is transparent for synchronous fetchers', ->
    it 'by proxying an argument', ->
      target = 'not_yet_filled'
      setter = (data) -> target = data
      slot = make_slot()

      do slot -> setter 'fetched_data_1'
      expect(target).toEqual 'fetched_data_1'

    it 'by proxying two arguments', ->
      target = 'not_yet_filled'
      setter = (nondata, data) -> target = data
      slot = make_slot()

      do slot -> setter 'fetched_data_not', 'fetched_data_1'
      expect(target).toEqual 'fetched_data_1'

    it 'by proxying context', ->
      target = 'not_yet_filled'
      setter = (nondata) -> target = this.data
      slot = make_slot()

      do slot -> setter.apply {data: 'fetched_data_1'}
      expect(target).toEqual 'fetched_data_1'

    it 'by failing to call objects', ->
      slot = make_slot()
      slotted_callback = slot {not_a_function: 'foo'}
      expect(slotted_callback).toThrow "Object #<Object> has no method 'apply'"

  describe 'works with expected async callbacks', ->
    beforeEach -> jasmine.Clock.useMock()

    it 'that are called successively', ->
      target = 'not_yet_filled'
      setter = (data) -> target = data
      slot = make_slot()

      plantTimeout 100, slot -> setter 'fetched_data_1'

      expect(target).toEqual 'not_yet_filled'
      jasmine.Clock.tick(120)
      expect(target).toEqual 'fetched_data_1'

      plantTimeout 100, slot -> setter 'fetched_data_2'
      jasmine.Clock.tick(120)
      expect(target).toEqual 'fetched_data_2'

    it 'that override the slot', ->
      target = 'not_yet_filled'
      setter = (data) -> target = data
      slot = make_slot()

      plantTimeout 100, slot -> setter 'fetched_data_1'
      plantTimeout 200, slot -> setter 'fetched_data_2'

      expect(target).toEqual 'not_yet_filled'
      jasmine.Clock.tick(120)
      expect(target).toEqual 'not_yet_filled'
      jasmine.Clock.tick(120)
      expect(target).toEqual 'fetched_data_2'

  describe 'works with out of order async fetchers', ->
    beforeEach -> jasmine.Clock.useMock()

    it 'which would otherwise render older data', ->
      target = 'not_yet_filled'
      setter = (data) -> target = data
      slot = make_slot setter

      plantTimeout 200, slot -> setter 'fetched_data_1'
      plantTimeout 100, slot -> setter 'fetched_data_2'

      expect(target).toEqual 'not_yet_filled'
      jasmine.Clock.tick(120)
      expect(target).toEqual 'fetched_data_2'
      jasmine.Clock.tick(120)
      expect(target).toEqual 'fetched_data_2'

    it 'and the .clear() function', ->
      target = 'not_yet_filled'
      setter = (data) -> target = data
      slot = make_slot setter

      plantTimeout 200, slot -> setter 'fetched_data_1'
      plantTimeout 100, slot -> setter 'fetched_data_2'

      expect(target).toEqual 'not_yet_filled'
      slot.clear()
      jasmine.Clock.tick(120)
      expect(target).toEqual 'not_yet_filled'
      jasmine.Clock.tick(120)
      expect(target).toEqual 'not_yet_filled'

    it 'even when they are named functions', ->
      target = 'not_yet_filled'
      last_retval = 0
      dynamic_source = -> last_retval++
      setter = -> target = dynamic_source()
      slot = make_slot setter

      expect(target).toEqual 'not_yet_filled'
      setter()
      expect(target).toEqual 0
      setter()
      expect(target).toEqual 1

      plantTimeout 200, slot setter
      plantTimeout 100, slot setter

      expect(target).toEqual 1
      jasmine.Clock.tick(120)
      expect(target).toEqual 2
      jasmine.Clock.tick(120)
      expect(target).toEqual 2
