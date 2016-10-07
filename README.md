# msgflo-nodejs [![Build Status](https://travis-ci.org/msgflo/msgflo-nodejs.svg?branch=master)](https://travis-ci.org/msgflo/msgflo-nodejs)

[MsgFlo](https://github.com/msgflo/msgflo) is a distributed, polyglot FBP (flow-based-programming)
runtime. It integrates with other FBP tools like the [Flowhub](http://flowhub.io) visual programming IDE.

This library makes it easy to create MsgFlo participants in JavaScript/CoffeScript on node.js.

## Status

**Production**

* Used at [TheGrid](https://thegrid.io) for all workers using AMQP/RabbitMQ,
including in [imgflo-server](https://github.com/jonnor/imgflo-server)
* Also used by [noflo-runtime-msgflo](https://github.com/noflo/noflo-runtime-msgflo)
* Experimental support for MQTT and direct transports

## Licence

MIT, see [./LICENSE](./LICENSE)

## Usage

Add as an NPM dependency

    npm install --save msgflo-nodejs

A simple participant (CoffeeScript)

    msgflo = require 'msgflo-nodejs'

    RepeatParticipant = (client, role) ->
      definition =
        component: 'Repeat'
        icon: 'file-word-o'
        label: 'Repeats in data without changes'
        inports: [
          id: 'in'
          type: 'any'
        ]
        outports: [
          id: 'out'
          type: 'any'
        ]
      process = (inport, indata, callback) ->
        return callback 'out', null, indata
      return new msgflo.participant.Participant client, definition, process, role

    client = msgflo.transport.getClient 'amqp://localhost'
    worker = RepeatParticipant client, 'repeater'
    worker.start (err) ->
      throw err if err
      console.log 'Worker started'

If you expose the participant factory function ([examples/Repeat.coffee](./examples/Repeat.coffee))

    module.exports = RepeatParticipant

Then you can use the `msgflo-nodejs` exectutable to start participant

    msgflo-nodejs --name repeater ./examples/Repeat.coffee

## Debugging

msgflo-nodejs uses the [debug NPM module](https://www.npmjs.com/package/debug).
You can enable (all) logging using:

    export DEBUG=msgflo*

## Supporting other transports

msgflo-nodejs has a transport abstraction layer. So to support a new messaging system,
implement `Client` and `MessageBroker` [interfaces](./src/interfaces.coffee).

You can then pass the Client instance into a `Participant`.

Or you can register a new transport using `msgflo.transport.register('mytransport', myTransportModule)`.
Then you can get a Client instance using `msgflo.transport.getClient('mytransport://somehost:666')`.
This has the advantage of also working when specifying the broker URL using
`msgflo-nodejs --broker` or `MSGFLO_BROKER=` environment variable.

