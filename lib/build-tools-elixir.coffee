compiler = require './compiler-errors'
exunit = require './exunit'

module.exports = BuildToolsElixir =

  provideProfiles: ->
    'elixir-compiler': compiler
    'elixir-exunit': exunit

  provideProvider: ->
    key: 'elixir-mix'
    mod: require './mix'
