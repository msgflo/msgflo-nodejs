
debug = require('debug')('msgflo:amqp')
async = require 'async'
uuid = require 'uuid'

interfaces = require './interfaces'

try
  amqp = require 'amqplib/callback_api'
catch e
  amqp = e

class Client extends interfaces.MessagingClient
  constructor: (address, options={}) ->
    super address, options
    @address = address
    @options = options
    @connection = null
    @channel = null
    @options.prefetch = 2 if not @options.prefetch?

  ## Broker connection management
  connect: (callback) ->
    debug 'connect', @address
    if amqp.message
      return callback amqp

    amqp.connect @address, (err, conn) =>
      debug 'connected', err
      return callback err if err
      @connection = conn
      conn.createChannel (err, ch) =>
        debug 'channel created', err
        return callback err if err
        @channel = ch
        debug 'setting prefetch', @options.prefetch
        @channel.prefetch @options.prefetch
        @channel.on 'close', () ->
          debug 'channel closed'
        @channel.on 'error', (err) ->
          throw err if err
        return callback null

  disconnect: (callback) ->
    debug 'disconnect'
    return callback null if not @connection
    return callback null if not @channel
    @channel.close (err) =>
      debug 'channel closed', err
      @channel = null
      @connection.close (err) =>
        debug 'connection closed'
        @connection = null
        return callback err

  ## Manipulating queues
  createQueue: (type, queueName, options, callback) ->
    if not callback
      callback = options
      options = {}

    debug 'create queue', type, queueName, options
    queueOptions =
      deadLetterExchange: 'dead-'+queueName # if not existing, messages will be dropped
    exchangeOptions = {}
    exchangeName = queueName

    if options.persistent? and not options.persistent
      queueOptions.durable = false
      queueOptions.autoDelete = true
      exchangeOptions.durable = false
      exchangeOptions.autoDelete = true

    if type == 'inqueue'
      @channel.assertQueue queueName, queueOptions, (err) =>
        # HACK: to make inqueue==outqueue work without binding.
        # Has side-effect of creating an implicit exchange.
        # Better than implicit queue, since a queue holds messages forever if noone is subscribed
        @channel.assertExchange exchangeName, 'fanout', exchangeOptions, (err) =>
          return callback err if err
          @channel.bindQueue exchangeName, queueName, '', {}, callback
    else
      @channel.assertExchange exchangeName, 'fanout', exchangeOptions, callback

  removeQueue: (type, queueName, callback) ->
    debug 'remove queue', type, queueName
    if type == 'inqueue'
      @channel.deleteQueue queueName, {}, callback
    else
      exchangeName = queueName
      @channel.deleteExchange exchangeName, {}, callback

  ## Sending/Receiving messages
  sendTo: (type, name, message, callback) ->
    return callback new Error 'msgflo.amqp.sendTo():  Not connected' if not @channel
    # queue must exists
    data = new Buffer JSON.stringify message
    showLimit = 80
    dataShow = if data.length > showLimit then data.slice(0, showLimit)+'...' else data
    debug 'sendTo', type, name, dataShow
    if type == 'inqueue'
      # direct to queue
      exchange = ''
      routingKey = name
    else
      # to fanout exchange
      exchange = name
      routingKey = ''
    @channel.publish exchange, routingKey, data
    return callback null


  subscribeToQueue: (queueName, handler, callback) ->
    return callback new Error 'msgflo.amqp.subscribeToQueue():  Not connected' if not @channel
    debug 'subscribe', queueName
    # queue must exists
    deserialize = (message) =>
      debug 'receive on queue', queueName, message.fields.deliveryTag
      data = null
      try
        data = JSON.parse message.content.toString()
      catch e
        data = message.content.toString()
      out =
        amqp: message
        data: data
      return handler out
    @channel.consume queueName, deserialize
    debug 'subscribed', queueName
    return callback null

  ## ACK/NACK messages
  ackMessage: (message) ->
    return if not @channel
    fields = message.amqp.fields
    debug 'ACK', fields.routingKey, fields.deliveryTag
    # NOTE: server will only give us new message after this
    @channel.ack message.amqp, false
  nackMessage: (message) ->
    return if not @channel
    fields = message.amqp.fields
    debug 'NACK', fields.routingKey, fields.deliveryTag
    @channel.nack message.amqp, false, false

  # Participant registration
  registerParticipant: (part, callback) ->
    msg =
      protocol: 'discovery'
      command: 'participant'
      payload: part
    @channel.assertQueue 'fbp'
    data = new Buffer JSON.stringify msg
    @channel.sendToQueue 'fbp', data
    return callback null


dataSubscriptionQueueName = (id) ->
  throw new Error("Missing id") if not id
  return ".msgflo-broker-subscriptions-#{id}"

bindingId = (b) ->
  return "[#{b.src}]->[#{b.tgt}]"

class MessageBroker extends Client
  constructor: (address, options) ->
    super address, options
    @options.id = uuid.v4() if not @options.id
    @subscriptions = {}

  connect: (callback) ->
    super (err) =>
      return callback err if err
      # create queue for data subscriptions
      name = dataSubscriptionQueueName @options.id
      options =
        exclusive: true
        durable: false
        autoDelete: true
      @channel.assertQueue name, options, (err) =>
        return callback err if err
        onSubscribedQueueData = (message) =>
          exchange = message.fields.exchange
          debug 'broker subscriber got message on exchange', exchange
          matches = Object.keys(@subscriptions).filter (id) =>
            sub = @subscriptions[id]
            # XXX: how to account for which queue the message is for
            # can we create some identifier when we subscribe?
            return sub?.binding.src == exchange
          for id in matches
            sub = @subscriptions[id]
            data = message.content
            try
              data = JSON.parse message.content.toString()
            catch e
              null
            sub.handler sub.binding, data

        subscribeOptions =
          noAck: true
        @channel.consume name, onSubscribedQueueData, subscribeOptions, (err) ->
          debug 'broker created subscription queue', err
          return callback err

  addBinding: (binding, callback) ->
    debug 'Broker.addBinding', binding
    if binding.type == 'pubsub'
      @channel.bindQueue binding.tgt, binding.src, '', {}, callback
    else if binding.type == 'roundrobin'
      pattern = ''
      bindSrcTgt = (callback) =>
        # TODO: avoid creating the direct exchange?
        debug 'binding src to tgt', binding.src, binding.tgt
        directExchange = 'out-'+binding.src
        directOptions = {}
        @channel.assertExchange directExchange, 'direct', directOptions, (err) =>
          return callback err if err
          # bind input
          @channel.bindExchange directExchange, binding.src, pattern, (err), =>
            return callback err if err
            # bind output
            @channel.bindQueue binding.tgt, directExchange, pattern, {}, (err) =>
              return callback err

      bindDeadLetter = (callback) =>
        # Setup the deadletter exchange, bind to deadletter queue
        debug 'binding deadletter queue', binding.deadletter, binding.tgt
        deadLetterExchange = 'dead-'+binding.tgt
        deadLetterOptions = {}
        @channel.assertExchange deadLetterExchange, 'fanout', deadLetterOptions, (err) =>
          return callback err if err
          @channel.bindQueue binding.deadletter, deadLetterExchange, pattern, {}, callback

      steps = []
      steps.push bindSrcTgt if binding.src and binding.tgt
      steps.push bindDeadLetter if binding.deadletter and binding.tgt
      async.series steps, callback

    else
      return callback new Error 'Unsupported binding type: '+binding.type

  removeBinding: (binding, callback) ->
    debug 'Broker.removeBinding', binding
    if binding.type == 'pubsub'
      @channel.unbindQueue binding.tgt, binding.src, '', {}, callback
    else if binding.type == 'roundrobin'
      return callback new Error "removeBinding() not supported for type='roundrobin'" # TODO:
    else
      return callback new Error "Unsupported binding type: #{binding.type}"


  listBindings: (from, callback) -> # FIXME: implement
    # NOTE: probably need to use the RabbitMQ HTTP API for this
    return callback null, []

  # Data subscriptions
  subscribeData: (binding, datahandler, callback) ->
    exchange = binding.src
    queue = dataSubscriptionQueueName @options.id
    options =
      autoDelete: true
    @channel.bindQueue queue, exchange, '', options, (err) =>
      return callback err if err
      id = bindingId binding
      @subscriptions[id] =
        binding: binding
        handler: datahandler
      return callback null

  unsubscribeData: (binding, datahandler, callback) ->
    # TODO: also remove the subscription with broker
    id = bindingId binding
    delete @subscriptions[id]
    return callback null

  listSubscriptions: (callback) ->
    # Is there a way to get this information through AMQP?
    # Or do need to use RabbitMQ HTTP API?
    subs = []
    for id, sub of @subscriptions
      subs.push sub.binding
    return callback null, subs

  # Participant registration
  subscribeParticipantChange: (handler) ->
    deserialize = (message) =>
      debug 'receive on fbp', message.fields.deliveryTag
      data = null
      try
        data = JSON.parse message.content.toString()
      catch e
        debug 'JSON exception:', e
      out =
        amqp: message
        data: data
      return handler out

    @channel.assertQueue 'fbp'
    @channel.consume 'fbp', deserialize

exports.Client = Client
exports.MessageBroker = MessageBroker
