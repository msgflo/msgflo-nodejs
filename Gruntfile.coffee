module.exports = ->
  # Project configuration
  @initConfig
    pkg: @file.readJSON 'package.json'

    # CoffeeScript compilation
    coffee:
      library:
        options:
          bare: true
        expand: true
        cwd: 'src'
        src: ['**.coffee']
        dest: 'lib'
        ext: '.js'

    # BDD tests on Node.js
    mochaTest:
      nodejs:
        src: ['spec/*.coffee']
        options:
          reporter: 'spec'
          require: [
            'coffeescript/register'
          ]
          grep: process.env.TESTS

    # Protocol tests
    shell:
      msgflo:
        command: 'node bin/msgflo'
        options:
          async: true
      fbp_test:
        command: 'fbp-test --colors'


  # Grunt plugins used for building

  # Grunt plugins used for testing
  @loadNpmTasks 'grunt-mocha-test'
  @loadNpmTasks 'grunt-shell-spawn'
  @loadNpmTasks 'grunt-contrib-coffee'

  # Our local tasks
  @registerTask 'fbp-test', [
    'shell:msgflo'
    'shell:fbp_test'
    'shell:msgflo:kill'
  ]

  @registerTask 'build', 'Build the chosen target platform', ['coffee']

  @registerTask 'test', 'Build and run automated tests', (target = 'all') =>
    @task.run 'build'
    @task.run 'mochaTest'
#    @task.run 'fbp-test'

  @registerTask 'default', ['test']
