Command = null

path = require 'path'

{View, TextEditorView} = require 'atom-space-pen-views'

module.exports =

  name: 'Elixir - Mix Targets'
  singular: 'Mix Target'

  activate: (command, project, input) ->
    Command = command

  deactivate: ->
    Command = null

  model:
    class ProviderModel
      constructor: ([@projectPath, @filePath], @config, @_save = null) ->
        @commands = null
        @error = null

      save: ->
        @_save()

      destroy: ->
        @error = null
        @commands = null

      getCommandByIndex: (id) ->
        return @commands[id] if @commands?
        new Promise((resolve, reject) =>
          @loadCommands().then (=>
            return reject() unless @commands[id]?
            resolve(@commands[id])
          ), reject
        )

      getCommandCount: ->
        return @commands.length if @commands?
        new Promise((resolve, reject) =>
          @loadCommands().then (=> resolve(@commands.length)), reject
        )

      getCommandNames: ->
        return (c.name for c in @commands) if @commands?
        new Promise((resolve, reject) =>
          @loadCommands().then (=> resolve((c.name for c in @commands))), reject
        )

      loadCommands: ->
        new Promise((resolve, reject) =>
          return reject(@error) if @error?
          return resolve() if @commands?
          commands = []
          regs = []
          for line in @config.filters.split('\n')
            if (m = /^([.\w]+):(.+)$/.exec(line))?
              regs.push [m[1], new RegExp(m[2])]
          if @config.cache?
            @commands = (new Command(c) for c in @config.cache)
            resolve()
          else
            require('child_process').exec(
              'mix --help'
              {cwd: path.join(@projectPath, @config.cwd)}
              (error, stdout, stderr) =>
                return reject(error) if error?
                for line in stdout.split('\n')
                  if (m = /^mix ([^\s]+)\s+# (.+)$/.exec(line))?
                    for [env, reg] in regs
                      if reg.test(m[1])
                        c = new Command(@config.props)
                        c.project = @projectPath
                        c.source = @filePath
                        c.name = "#{m[1]} (#{env}) - #{m[2]}"
                        c.command = "mix #{m[1]}"
                        c.wd = @config.cwd
                        if env isnt 'default'
                          c.env['MIX_ENV'] = env
                        c.stdout.pipeline = [
                          {
                            name: "profile"
                            config:
                              profile: "elixir-compiler"
                          }
                          {
                            name: "profile"
                            config:
                              profile: "elixir-exunit"
                          }
                        ]
                        commands.push c
                @commands = commands
                resolve()
            )
        )

  view:
    class MixView extends View
      @content: ->
        @div class: 'inset-panel', =>
          @div class: 'top panel-heading', =>
            @div =>
              @span id: 'provider-name', class: 'inline-block panel-text'
              @span id: 'apply', class: 'inline-block btn btn-xs icon icon-check', 'Apply'
              @span id: 'edit', class: 'inline-block btn btn-xs icon icon-pencil', 'Edit Command Parameters'
              @span id: 'cache', class: 'inline-block btn btn-xs icon icon-database', 'Cache mix targets'
              @span id: 'clear', class: 'inline-block btn btn-xs icon icon-x', 'Clear target cache'
              @span outlet: 'cachestatus', class: 'badge badge-small badge-info icon icon-check', '0 Targets cached'
            @div class: 'config-buttons align', =>
              @div class: 'icon-triangle-up'
              @div class: 'icon-triangle-down'
              @div class: 'icon-x'
          @div class: 'panel-body padded', =>
            @div class: 'block', =>
              @label =>
                @div class: 'settings-name', 'Working Directory'
                @div =>
                  @span class: 'inline-block text-subtle', 'Working Directory for mix-commands'
              @subview 'cwd', new TextEditorView(mini: true, placeholderText: '.')
            @div class: 'block', =>
              @label =>
                @div class: 'settings-name', 'Target Filters'
                @div =>
                  @span class: 'inline-block text-subtle', 'Each line has the syntax ENV:REGEX. If a command matches REGEX, a command with MIX_ENV=ENV will be shown (use default:... if you want to provide commands without MIX_ENV).'
              @subview 'filters', new TextEditorView(mini: false)

      initialize: (@project) ->
        @updateCacheStatus()
        @filters.getModel().setMini(false)
        @cwd.getModel().setText(@project.config.cwd ? '')
        @filters.getModel().setText(@project.config.filters ? 'default:.')

      setCallbacks: (@hidePanes, @showPane) ->

      updateCacheStatus: ->
        if @project.config.cache?
          @cachestatus.text "#{@project.config.cache.length} Targets cached"
          @cachestatus[0].className = 'badge badge-small badge-success icon icon-check'
        else
          @cachestatus.text "0 Targets cached"
          @cachestatus[0].className = 'badge badge-small badge-error icon icon-x'

      attached: ->
        @on 'click', '#apply', =>
          cwd = @cwd.getModel().getText()
          filters = @filters.getModel().getText()
          cwd = '.' if cwd.trim() is ''
          filters = 'default:.' if filters.trim() is ''
          @project.config.cwd = cwd
          @project.config.filters = @filters.getModel().getText()
          @project.save()
        @on 'click', '#edit', =>
          protocommand = new Command(@project.config.props)
          protocommand.project = @projectPath
          protocommand.name = ''
          p = atom.views.getView(protocommand)
          p.sourceFile = @project.filePath
          p.setBlacklist ['general', 'wildcards', 'highlighting']
          p.setCallbacks(((out) =>
            @project.config.props = out
            @project.save()
          ), @hidePanes)
          @showPane p
        @on 'click', '#cache', =>
          @project.loadCommands().then(=>
            @project.config.cache = @project.commands
            @updateCacheStatus()
            @project.save()
          )
        @on 'click', '#clear', =>
          @project.config.cache = null
          @project.save()
          @updateCacheStatus()
