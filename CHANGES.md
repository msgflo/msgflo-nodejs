# msgflo-nodejs 0.11.0, 03.11.2017

Breaking changes

* Reqires Node.js 6.0+ for JavaScript ES6 support.

Internal changes

* Update to CoffeeScript 2

# msgflo-nodejs 0.10.0, 15.03.2017

* Transport: Add interface for listing existing datasubscriptions.
`MessageBroker.listSubscriptions()`

# msgflo-nodejs 0.9.0, 04.02.2017

* Transport: Add new interface for subscribing to data changes on a binding.
See MessageBroker `subscribeData()` and `unsubscribeData()`.
* MQTT: Support `subscribeData()`
* MQTT: Fix falsy messages not being forwarded
* MQTT: Fix addBinding() not working if a removeBinding() had been done before
* No support for subscribeData on AMQP yet

# msgflo-nodejs 0.8.2, 01.02.2017

* MsgFlo discovery message now sent periodically. Defaults to couple of times per minute.

# msgflo-nodejs 0.7.2, 09.10.2016

* MQTT: Fix compatibility with newer versions of library (> 1.4.x)

# msgflo-nodejs 0.7.1, 09.10.2016

* Client/AMQP/MQTT: Remove deprecated `sendToQueue()`.

# msgflo-nodejs 0.6.0, 10.09.2016

* participant: Remove deprecated `connectGraphEdges()` and `connectGraphFile()`.
Should use `msgflo.setup` instead.
* MQTT: Implement `removeBinding()`, for removing a connection

# msgflo-nodejs 0.5.0, 06.06.2016

* Allows to register custom transports using `msgflo_nodejs.transport.register()`
* Transport dependencies (`amqplib` and `mqtt`) are no longer included by default.
So the project using msgflo-nodejs must to add it to their own dependencies.
* No longer requires CoffeeScript at runtime; the NPM package is plain JS

# msgflo.nodejs 0.4.0, 04.06.2015

First version split out of [msgflo](https://github.com/msgflo/msgflo).
