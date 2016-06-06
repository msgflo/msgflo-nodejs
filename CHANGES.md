
# msgflo-nodejs 0.5.0, 06.06.2016

* Allows to register custom transports using `msgflo_nodejs.transport.register()`
* Transport dependencies (`amqplib` and `mqtt`) are no longer included by default.
So the project using msgflo-nodejs must to add it to their own dependencies.
* No longer requires CoffeeScript at runtime; the NPM package is plain JS

# msgflo.nodejs 0.4.0, 04.06.2015

First version split out of [msgflo](https://github.com/msgflo/msgflo).
