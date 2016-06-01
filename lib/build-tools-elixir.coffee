compiler = require './compiler-errors'

module.exports = BuildToolsElixir =

  provideProfiles: ->
    'elixir-compiler': compiler
