
transports =
  amqp: require './amqp'
  mqtt: require './mqtt'
  direct: require './direct'

transports.amqps = transports.amqp

supportsScheme = (scheme) ->
  return scheme in Object.keys transports

exports.getClient = (address, options) ->
  scheme = address.split('://')[0]
  throw new Error 'Unsupported scheme: ' + scheme if not supportsScheme scheme
  client = new transports[scheme].Client address, options
  return client

exports.getBroker = (address, options) ->
  scheme = address.split('://')[0]
  throw new Error 'Unsupported scheme: ' + scheme if not supportsScheme scheme
  return new transports[scheme].MessageBroker address, options

# @module: Must have Client and MessageBroker constructors, implementing these interfaces
exports.register = (scheme, module) ->
  transports[scheme] = module
