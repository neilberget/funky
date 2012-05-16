Funky = {}

# Mixin method and utility methods that are Mixin-able
window.include = (obj, mixins...) ->
  for mixin in mixins
    for name, method of mixin
      obj::[name] = method
  
merge = (obj, original...) ->
  original.forEach (source) ->
    for prop of source
       unless obj[prop]?
         obj[prop] = source[prop]

  obj

removeOn = (string) ->
	string.replace /^on([A-Z])/, (full, first) ->
		first.toLowerCase()
 

# Mixins
# ======

# TODO: removeEvent, removeEvents
Funky.Events =
  events: []

  fireEvent: (eventName, args...) ->
    eventName = removeOn eventName

    @events[eventName]?.forEach (e) ->
      e.apply @, args

    @

  addEvent: (eventName, fn) ->
    eventName = removeOn eventName

    @events ?= []
    @events[eventName] ?= []
    @events[eventName].push fn
    
    @

  addEvents: (events) ->
    @addEvent eventName, fn for eventName, fn of events

    @

Funky.Options =
  setOptions: (args) ->
    options = @options = merge args, @options
    if @addEvent
      for key, value of options
        continue if typeof(value) != 'function' || not (/^on[A-Z]/).test(key)
        @addEvent key, value

    @


# MVC scaffolding
# ===============

class Funky.View
  # set to false in classes subclassing this if you set el dynamically later
  # and therefore call delegateEvents at that time, rather than automatically
  # in the constructor
  autoDelegateEvents: true

  constructor: (@opts) ->
    @model = @opts.model if @opts?.model?
    @delegateEvents() if @autoDelegateEvents

  delegateEvents: ->
    for key of @events
      match = key.match(/^(\S+)\s*(.*)$/)
      eventName = match[1]
      selector = match[2]
      @el ?= document
      method = @[@events[key]]
      $(@el).on eventName, selector, method

  serialize: ->
    inputs = $("input[type!=submit]", @el)
    _.reduce inputs, (memo, i) ->
      memo[$(i).attr("name")] = $(i).val()
      memo
    , {}

class Funky.Collection
  include @, Funky.Events

  constructor: (objs) ->
    if @klass
      @objs = (new @klass obj for obj in objs)
    else
      @objs = objs

    obj.addEvent("delete", @deleteObject) for obj in @objs


  get: (id) ->
    (obj for obj in @objs when parseInt(obj.id) == parseInt(id))[0]

  pluck: (field) ->
    _.map @objs, (obj) -> obj.get field

  size: ->
    @objs.length

  previous: (id) ->
    return null unless id?

    current = _.indexOf @pluck('id'), id.toString()
    @objs[current-1]

  next: (id) ->
    return null unless id?

    current = _.indexOf @pluck('id'), id.toString()
    @objs[current+1]

  deleteObject: (deleted) =>
    @objs = @reject (obj) -> obj == deleted
    @fireEvent "delete", deleted

  add: (attrs) =>
    added = new @klass attrs
    @objs.push added
    added.save()
    @fireEvent "add", added


methods = ['forEach', 'each', 'map', 'filter', 'find', 'reject']

_.each methods, (method) ->
  Funky.Collection::[method] = ->
    _[method].apply _, [@objs].concat _.toArray arguments


class Funky.Model
  include @, Funky.Events

  constructor: (@attrs) ->
    @id = @attrs.id

  get: (field) ->
    @attrs[field]

  set: (field, value) ->
    @attrs[field] = value

  update: (attrs) ->
    @attrs = _.extend @attrs, attrs

    $.ajax @url(),
      type: "POST"
      data: attrs
      success: =>
        @fireEvent "update", @

  save: ->
    $.ajax @url(),
      type: "POST"
      data: @attrs
      success: =>
        @fireEvent "save", @

  delete: ->
    $.ajax @url(),
      type: "DELETE"
      success: =>
        @fireEvent "delete", @

window.Funky = Funky
