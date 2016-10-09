
# msgflo-nodejs 0.7.0, 09.10.2016

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
