
interfaces = require './interfaces'
EventEmitter = require('events').EventEmitter

brokers = {}

class Client extends interfaces.MessagingClient
  constructor: (@address) ->
#    console.log 'client', @address
    @broker = brokers[@address]
  
  ## Manipulating queues
  createQueue: (queueName, callback) ->
    # just call broker directly
    return callback null

  removeQueue: (queueName, callback) ->
    # just call broker directly
    return callback null

  ## Sending/Receiving messages
  sendToQueue: (queueName, message, callback) ->
    @broker.sendToQueue queueName, message, callback

  subscribeToQueue: (queueName, handler) ->
    @broker.subscribeToQueue queueName, handler


class Queue extends EventEmitter
  constructor: () ->

  send: (msg) ->
    @_emitSend msg

  _emitSend: (msg) ->
    @emit 'message', msg

class MessageBroker extends interfaces.MessageBroker
  constructor: (@address) ->
    @queues = {}
#    console.log 'broker', @address
    brokers[@address] = this

  ## Manipulating queues
  createQueue: (queueName, callback) ->
    @queues[queueName] = new Queue if not @queues[queueName]?
    return callback null

  removeQueue: (queueName, callback) ->
    delete @queues[queueName]
    return callback null

  ## Sending/Receiving messages
  sendToQueue: (queueName, message, callback) ->
#    console.log 'broker sendToQueue', queueName, @queues[queueName].send
    @queues[queueName].send message
    return callback null

  subscribeToQueue: (queueName, handler) ->
    @queues[queueName] = new Queue if not @queues[queueName]?
    @queues[queueName].on 'message', handler

exports.MessageBroker = MessageBroker
exports.Client = Client

