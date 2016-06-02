module.exports =
  class ElixirCompilerProfile

    @profile_name: 'Elixir - ExUnit (Default Formatter)'

    scopes: ['source.elixir']

    default_extensions: ['ex', 'exs']

    strings:
      file: '(?<file> [\\S]+\\.(?extensions)):(?<row> \\d+)'
      start: '^(?<indent>\\s+\\d+\\)\\s)test\\s(?<message> .+)$'
      stacktrace: '^\\((?<name>[^\\)]+)\\)\\s(?<file> [\\S]+\\.(?:(?extensions)|erl)):(?<row> \\d+)(?::\\s(?<message> .+))?$'

    constructor: (@output) ->
      @extensions = @output.createExtensionString @scopes, @default_extensions
      @exps = {}
      for key, string of @strings
        @exps[key] = @output.createRegex string, @extensions

    files: (line) ->
      start = 0
      out = []
      while (m = @exps.file.xexec line.substr(start))?
        start += m.index
        m.start = start
        m.end = start + m.file.length + (if m.row? then m.row.length + 1 else -1)
        m.row = '0' if not m.row?
        m.col = '0'
        start = m.end + 1
        out.push m
      out

    in: (td, perm) ->
      input = td.input
      perm.elixirExUnitState ?=
        state: 0 # No state
      curr = perm.elixirExUnitState
      if curr.state is 1 # Look for file path
        input = input.substr(curr.indent)
        if (m = @exps.file.xexec input)?
          curr.file = m.file
          curr.row = m.row
          curr.state = 2
        else
          curr.state = 0
        td.type = 'error'
      else if curr.state is 2 # Look for data
        input = input.substr(curr.indent)
        if input is 'stacktrace:'
          curr.state = 3
        else
          curr.date += input + '\n'
        td.type = 'error'
      else if curr.state is 3 # Look for stack trace
        input = input.substr(curr.indent + 2) # Remove indentation
        if (m = @exps.stacktrace.xexec input)? # Matching stack trace
          m.type = 'Trace'
          m.message ?= 'Here'
          curr.trace.push @output.createMessage m
        else # End of stack trace
          @output.lint curr
          curr.state = 0
        td.type = 'error'
      if curr.state is 0 # Look for start
        if (m = @exps.start.xexec input)? # Matching error
          curr.state = 1 # Set to trace state
          curr.indent = m.indent.length # Save indentation
          curr.type = 'error'
          curr.message = m.message
          curr.trace = []
          curr.date = ''
          td.type = 'error'
      null
