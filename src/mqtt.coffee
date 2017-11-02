
debug = require('debug')('msgflo:mqtt')
interfaces = require './interfaces'
routing = require './routing'

try
  mqtt = require 'mqtt'
catch e
  mqtt = e

class Client extends interfaces.MessagingClient
  constructor: (address, options) ->
    super address, options
    @address = address
    @options = options
    @client = null
    @subscribers = {} # queueName -> [handler1, ...]

  ## Broker connection management
  connect: (callback) ->
    if mqtt.message
      return callback mqtt

    @client = mqtt.connect @address

    # debug
    @client.on 'reconnect', () =>
      debug 'reconnect'
    @client.on 'offline', () =>
      debug 'offline'

    @client.on 'error', (err) =>
      debug 'error', err
      if callback
        callback err
        callback = null
        return
    onConnected = (connack) =>
      debug 'connected'
      @client.on 'message', (topic, message) =>
        @_onMessage topic, message
      if callback
        callback null
        callback = null
        return
    @client.once 'connect', onConnected

  disconnect: (callback) ->
    @client.removeAllListeners 'message'
    @client.removeAllListeners 'connect'
    @client.removeAllListeners 'reconnect'
    @client.removeAllListeners 'offline'
    @client.removeAllListeners 'error'
    @subscribers = {}
    @client.end (err) =>
      debug 'disconnected'
      @client = null
      return callback err

  ## Manipulating queues
  createQueue: (type, queueName, options, callback) ->
    if not callback
      callback = options
      options = {}

    # Noop, in MQTT one can send messages on 'topics' at any time
    return callback null

  removeQueue: (type, queueName, callback) ->
    # Noop, in MQTT one can send messages on 'topics' at any time
    return callback null

  ## Sending/Receiving messages
  sendTo: (type, queueName, message, callback) ->
    published = (err, granted) =>
      debug 'published', queueName, err, granted
      return callback err if err
      return callback null
    data = JSON.stringify message
    debug 'publishing', queueName, data
    @client.publish queueName, data, published

  subscribeToQueue: (queueName, handler, callback) ->
    debug 'subscribing', queueName
    @client.subscribe queueName, (err) =>
      debug 'subscribed', queueName, err
      return callback err if err
      subs = @subscribers[queueName]
      if subs then subs.push handler else @subscribers[queueName] = [ handler ]
      return callback null

  ## ACK/NACK messages
  ackMessage: (message) ->
    return
  nackMessage: (message) ->
    return

  _onMessage: (topic, message) ->
    return if not @client
    return if not Object.keys(@subscribers).length > 0

    msg = null
    try
      msg = JSON.parse message.toString()
    catch e
      debug "failed to parse incoming message on #{topic} as JSON", e
      msg = message.toString()
    handlers = @subscribers[topic]

    debug 'message', handlers.length, msg != null
    return if not handlers
    out =
      data: msg
      mqtt: message
    for handler in handlers
      handler out

  registerParticipant: (part, callback) ->
    msg =
      protocol: 'discovery'
      command: 'participant'
      payload: part
    @sendTo 'inqueue', 'fbp', msg, callback

class MessageBroker extends Client
  constructor: (address, options) ->
    super address, options
    routing.binderMixin this

  # Participant registration
  subscribeParticipantChange: (handler) ->
    @createQueue '', 'fbp', (err) =>
      @subscribeToQueue 'fbp', handler, () ->

exports.Client = Client
exports.MessageBroker = MessageBroker
