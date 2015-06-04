MsgFlo - Flow-Based Programming with Message Queues [![Build Status](https://travis-ci.org/the-grid/msgflo-nodejs.svg?branch=master)](https://travis-ci.org/the-grid/msgflo-nodejs)
===================================================

[MsgFlo](https://github.com/the-grid/msgflo) is a distributed, polyglot FBP (flow-based-programming)
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

A simple participant (CoffeeScript)

    msgflo = require 'msgflo'

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

    client =  msgflo.transport.getClient 'amqp://localhost'
    worker = new RepeatParticipant client, 'repeater'
    worker.start (err) ->
      throw err if err
      console.log 'Worker started'


## Debugging

The msgflo executable, as well as the transport/participant library
uses the [debug NPM module](https://www.npmjs.com/package/debug).
You can enable (all) logging using:

    export DEBUG=msgflo*

