
debug = require('debug')('msgflo:routing')

# Used to bind one queue/exchange to another when the Broker
# of the transport cannot provide this functionality, like on MQTT
#
# TODO: split into two pieces
# a) a Router, which implements message routing
# with a message-queue based protocol for listing and manipulating bindings.
# b) a Binder mixin for MessageBroker inteface,
# which sends messsages on this protocol for add/removeBinding() and listBindings()
#
# This allows a single Router to exist in the network. It holds the canonical state of which
# queues/topics are bound to eachother, and multiple processes can query and manipulate these.
# Typically this would be hosted on the same machine as the Broker itself, and would have same lifetime.
#
# Protocol:
# (in) /msgrouter/$instance/addbinding      Add a new binding between a source and target topic/queue.
# (in) /msgrouter/$instance/removebinding   Remove an existing binding between a source and target topic/queue.
# (out) /msgrouter/$instance/bindings       Full list of current bindings. Emitted on changes, or when requested.
# (in) /msgrouter/$instance/listbindings    Explicitly request current bindings.
#
# The default $instance is 'default'
# The Router implementation should persist the bindings whenever they change.
# Upon restarting it should restore the persisted bindings (and emit a signal).
#
bindingId = (f, t) ->
  return "#{f}-#{t}"

class Binder
  constructor: (@transport) ->
    @bindings = {}

  addBinding: (binding, callback) ->
    from = binding.src
    to = binding.tgt
    # TODO: handle non-pubsub types
    id = bindingId from, to
    debug 'Binder.addBinding', binding.type, id
    return callback null if @bindings[id] or from == to

    handler = (msg) =>
      binding = @bindings[id]
      return if not binding?.enabled
      debug 'edge message', from, to, msg
      @transport.sendTo 'outqueue', to, msg.data, (err) ->
        throw err if err
    @transport.subscribeToQueue from, handler, (err) =>
      return callback err if err
      @bindings[id] =
        handler: handler
        enabled: true
      return callback null

  removeBinding: (binding, callback) ->
    from = binding.src
    to = binding.tgt
    id = bindingId from, to
    debug 'Binder.removeBinding', binding, id
    binding = @bindings[id]
    return callback new Error "Binding does not exist" if not binding
    binding.enabled = false
    delete @bindings[id]
    #FIXME: add an unsubscribeQueue to Client/transport, and use that
    return callback null

  listBindings: (callback) ->  # FIXME: implement
    debug 'Binder.listBindings'
    return callback null, []


exports.Binder = Binder
exports.binderMixin = (transport) ->
  b = new Binder transport
  transport._binder = b
  transport.addBinding = b.addBinding.bind b
  transport.removeBinding = b.removeBinding.bind b
  transport.listBindings = b.listBindings.bind b

