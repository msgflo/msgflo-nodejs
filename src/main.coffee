
program = require 'commander'
path = require 'path'

parse = (args) ->
  program
    .arguments('<FILE>')
    .action((mod, env) ->
      program.modulefile = mod
    )
    .option('--name <role>', 'Role name', String, '')
    .option('--broker <uri>', 'Broker address', String, '')
    .parse(args)
  return program

normalize = (options) ->

  options.broker = process.env['MSGFLO_BROKER'] if not options.broker
  options.broker = process.env['CLOUDAMQP_URL'] if not options.broker
  options.broker = 'amqp://localhost' if not options.broker
  options.modulefile = path.resolve process.cwd(), options.modulefile
  basename = (fp) ->
    path.basename(fp, path.extname(fp)).toLowerCase()
  options.name = basename options.modulefile if not options.modulefile
  return options

start = (options, callback) ->
  Part = require options.modulefile
  part = Part options.broker, options.name
  part.start (err) ->
    return callback err, part

exports.main = () ->

  options = parse process.argv
  options = normalize options
  start options, (err, part) ->
    throw err if err
    console.log "#{options.name} connected to #{options.broker}"

