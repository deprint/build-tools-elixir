module.exports =
  class ElixirCompilerProfile

    @profile_name: 'Elixir - Compiler Errors'

    scopes: ['source.elixir']

    default_extensions: ['ex', 'exs']

    strings:
      file: '(?<file> [\\S]+\\.(?extensions)):(?<row> \\d+)'
      error_begin: '^(?<indent>\\s*)\\*\\*\\s\\((?<error_type>[^\\)]+)\\)\\s(?<file> [\\S]+\\.(?extensions)):(?<row> \\d+):\\s(?<message> .+)$'
      error_trace: '^\\((?<name>[^\\)]+)\\)\\s(?<file> [\\S]+\\.(?:(?extensions)|erl)):(?<row> \\d+):\\s(?<message> .+)$'

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
      perm.elixirCompilerState ?=
        state: 0 # No state
      curr = perm.elixirCompilerState
      if curr.state is 1 # Look for stack trace
        input = input.substr(curr.indent + 4) # Remove indentation
        if (m = @exps.error_trace.xexec input)? # Matching stack trace
          m.type = 'Trace'
          curr.trace.push @output.createMessage m
        else # End of stack trace
          @output.lint curr
          curr.state = 0
        td.type = 'error'
      if curr.state is 0 # Look for error_begin
        if (m = @exps.error_begin.xexec input)? # Matching error
          curr.state = 1 # Set to trace state
          curr.indent = m.indent.length # Save indentation
          curr.type = 'error'
          curr.name = m.error_type
          curr.file = m.file
          curr.row = m.row
          curr.message = m.message
          curr.trace = []
          td.type = 'error'
      null
