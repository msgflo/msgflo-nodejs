
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
    @subscriptions = {}

  addBinding: (binding, callback) ->
    from = binding.src
    to = binding.tgt
    # TODO: handle non-pubsub types
    id = bindingId from, to
    debug 'Binder.addBinding', binding.type, id
    return callback null if @bindings[id] # already exists, avoid duplicate

    handler = (msg) =>
      binding = @bindings[id]
      return if not binding?.enabled
      debug 'edge message', from, to, msg

      subscription = @subscriptions[id]
      if subscription
        for subCallback in subscription.handlers
          subCallback(subscription.binding, msg.data)

      if from != to
        @transport.sendTo 'outqueue', to, msg.data, (err) ->
          throw err if err
      else
        # same topic/queue, data should appear without our forwarding

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

  subscribeData: (binding, datahandler, callback) ->
    id = bindingId binding.src, binding.tgt
    @subscriptions[id] = { handlers: [], binding: binding } if not @subscriptions[id]
    @subscriptions[id].handlers.push datahandler
    return callback null
  unsubscribeData: (binding, datahandler, callback) ->
    id = bindingId binding.src, binding.tgt
    subscription = @subscriptions[id]
    handlerIndex = subscription.handlers.indexOf datahandler
    return callback new Error "Subscription was not found" if handlerIndex == -1
    subscription.handlers = subscription.handlers.splice(handlerIndex, 1)
    return callback null
  listSubscriptions: (callback) ->
    subs = []
    for id, sub of @subscriptions
      subs.push sub.binding
    return callback null, subs


exports.Binder = Binder
exports.binderMixin = (transport) ->
  b = new Binder transport
  transport._binder = b
  transport.addBinding = b.addBinding.bind b
  transport.removeBinding = b.removeBinding.bind b
  transport.listBindings = b.listBindings.bind b
  transport.subscribeData = b.subscribeData.bind b
  transport.unsubscribeData = b.unsubscribeData.bind b
  transport.listSubscriptions = b.listSubscriptions.bind b

