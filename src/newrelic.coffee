
debug = require('debug')('msgflo:newrelic')

if process.env.NEW_RELIC_LICENSE_KEY?
  nr = require 'newrelic'

class Transactions
  constructor: (@definition) ->
    @transactions = {}

  open: (id, port) ->
    return if not nr?
    @transactions[id] =
      id: id
      start: Date.now()
      inport: port

  close: (id, port) ->
    return if not nr?
    transaction = @transactions[id]
    if transaction
      duration = Date.now()-transaction.start
      event =
        role: @definition.role
        component: @definition.component
        inport: transaction.inport
        outport: port
        duration: duration
      name = 'MsgfloJobCompleted'
      nr.recordCustomEvent name, event
      debug 'recorded event', name, event
      delete @transactions[id]

exports.Transactions = Transactions
