
common = require './common'
transport = require './transport'

path = require 'path'
fs = require 'fs'
debug = require('debug')('msgflo:participant')
chance = require 'chance'
async = require 'async'
EventEmitter = require('events').EventEmitter
uuid = require 'uuid'
fbp = require 'fbp'

random = new chance.Chance 10202

findPort = (def, type, portName) ->
  ports = if type == 'inport' then def.inports else def.outports
  for port in ports
    return port if port.id == portName
  return null

definitionToFbp = (d) ->
  def = common.clone d
  portsWithQueue = (ports) ->
    # these cannot be wired, so should not show. For Sources/Sinks
    return ports.filter (p) -> return p.queue?

  def.inports = portsWithQueue def.inports
  def.outports = portsWithQueue def.outports
  return def

addQueues = (ports, role) ->
  for p in ports
    p.hidden = false if not p.hidden?
    name = role+'.'+p.id.toUpperCase()
    p.queue = name if not p.queue and not p.hidden

  return ports

instantiateDefinition = (d, role) ->
  def = common.clone d

  id = uuid.v4()
  def.role = role
  def.id = "#{def.role}-#{id}"

  def.inports = addQueues def.inports, def.role
  def.outports = addQueues def.outports, def.role

  return def

class Participant extends EventEmitter
  # @func gets called with inport, , and should return outport, outdata
  constructor: (client, def, @func, role) ->
    client = transport.getClient(client) if typeof client == 'string'
    @messaging = client
    role = 'unknown' if not role
    @definition = instantiateDefinition def, role
    @running = false
    newrelic = require './newrelic'
    @_transactions = new newrelic.Transactions role

  start: (callback) ->
    @messaging.connect (err) =>

      debug 'connected', err
      return callback err if err
      @setupPorts (err) =>
        @running = true
        return callback err if err
        @register (err) ->
          return callback err

  stop: (callback) ->
    @running = false
    @messaging.disconnect callback

  # Send data on inport
  # Normally only used directly for Source type participants
  # For Transform or Sink type, is called on data from input queue
  send: (inport, data, callback = -> ) ->
    debug 'got msg from send()', inport
    @func inport, data, (outport, err, data) =>
      return callback err if err
      @onResult outport, data, callback

  # Emit data on outport
  emitData: (outport, data) ->
    @emit 'data', outport, data

  onResult: (outport, data, callback) =>
    port = findPort @definition, 'outport', outport
    @emitData port.id, data
    if port.queue
      @messaging.sendTo 'outqueue', port.queue, data, callback
    else
      return callback null

  setupPorts: (callback) ->
    setupOutPort = (def, callback) =>
      return callback null if not def.queue
      @messaging.createQueue 'outqueue', def.queue, callback

    setupInPort = (def, callback) =>
      return callback null if not def.queue

      callFunc = (msg) =>
        debug 'got msg from queue', def.queue
        msgid = uuid.v4() # need something cross-transport, only AMQP has deliveryTag
        @_transactions.open msgid, def.id
        @func def.id, msg.data, (outport, err, data) =>
          @_transactions.close msgid, outport
          return @messaging.nackMessage msg if err
          @onResult outport, data, (err) =>
            return @messaging.nackMessage msg if err
            @messaging.ackMessage msg if msg

      @messaging.createQueue 'inqueue', def.queue, (err) =>
        return callback err if err
        @messaging.subscribeToQueue def.queue, callFunc, callback
        debug 'subscribe to', def.queue

    async.map @definition.outports, setupOutPort, (err) =>
      return callback err if err
      async.map @definition.inports, setupInPort, (err) =>
        return callback err if err
        return callback null

  register: (callback) ->
    # Send discovery package to broker on 'fbp' queue
    debug 'register'
    definition = definitionToFbp @definition
    @messaging.registerParticipant definition, (err) =>
      debug 'registered', err
      return callback err

  # Sets up queues to match those defined in graph
  connectGraphEdges: (graph) ->
    console.log 'WARN: msgflo.Participant::connectGraphEdges() is deprecated. Use msgflo.setup.setupBindings() instead'
    processName = @definition.role

    # If there are outbound connections
    # Set the output queue to equal to the input queue of the target
    for conn in graph.connections
      if conn.src?.process == processName
        # WARN: assumes the queue naming convention,
        # as we don't have access to the definition of target participant
        # altenative would be to instantiate whole network,
        # and in worker case only run one participant?
        # using exchanges for the outports and binding to inports might also solve it
        tgtQueue = "#{conn.tgt.process}.#{conn.tgt.port.toUpperCase()}"
        ports = @definition.outports.filter (p) -> return p.id == conn.src.port
        ports[0].queue = tgtQueue

  connectGraphEdgesFile: (filepath, callback) ->
    console.log 'WARN: msgflo.Participant::connectGraphEdgesFile() is deprecated. Use msgflo.setup.setupBindings() instead'
    ext = path.extname filepath
    fs.readFile filepath, { encoding: 'utf-8' }, (err, contents) =>
      return callback err if err
      try
        if ext == '.fbp'
          graph = fbp.parse contents
        else
          graph = JSON.parse contents
        @connectGraphEdges graph
      catch e
        return callback e
      return callback null

# TODO: consider making component api a bit more like NoFlo.WirePattern
#
# inputs = { portA: { data: dataA1, groups: ['A', '1'] }, portB: { data: B1 } }
# outfunc = (type, outputs) -> # type can be 'data', 'end'
# process(inputs, outfunc)
#
# Core ideas:
# groups attached to the packet, avoids separate lifetime handling, but still allows modification
# should one enforce use of promises? calling process returns a promise?

startParticipant = (library, client, componentName, id, callback) ->
  debug 'starting', componentName, id

  component = library[componentName]
  return callback new Error "No Participant factory in library for #{componentName}" if not component?
  part = component client, id

  part.start (err) ->
    return callback err, part

exports.Participant = Participant
exports.startParticipant = startParticipant
exports.instantiateDefinition = instantiateDefinition
