Editor
======

    Runners = require "./runners"
    Actions = require("./actions")
    Builder = require("builder")
    Packager = require("packager")
    {Filetree, File} = require("filetree")
    {processDirectory} = require "./source/util"
    documenter = require "md"

    loadedPackage = Observable null

    initBuilder = (self) ->
      builder = Builder()

      # Add editor's metadata
      builder.addPostProcessor (pkg) ->
        pkg.progenitor =
          url: document.location.href

      # Add metadata from our config
      builder.addPostProcessor (pkg) ->
        config = readSourceConfig(pkg)

        pkg.version = config.version
        pkg.entryPoint = config.entryPoint or "main"
        pkg.remoteDependencies = config.remoteDependencies

      # Attach repo metadata to package
      builder.addPostProcessor (pkg) ->
        repository = self.repository()

        # TODO: Track commit SHA as well
        pkg.repository = cleanRepositoryData repository.toJSON()

        # Add publish branch
        pkg.repository.publishBranch = self.config().publishBranch or repository.publishBranch()

      return builder

    module.exports = (I={}, self=Model(I)) ->
      builder = initBuilder(self)
      filetree = Filetree()

      notifications = require("notifications")()
      {classicError, notify, errors} = notifications
      extend self,
        classicError: classicError
        notify: notify
        errors: errors
        notifications: notifications

      self.extend
        repository: Observable()

        confirmUnsaved: ->
          Q.fcall ->
            if filetree.hasUnsavedChanges()
              throw "Cancelled" unless window.confirm "You will lose unsaved changes in your current branch, continue?"

        publish: ->
          self.build()
          .then (pkg) ->
            documenter.documentAll(pkg)
            .then (docs) ->
              # NOTE: This metadata is added from the builder
              publishBranch = pkg.repository.publishBranch

              # TODO: Don't pass files to packager, just merge them at the end
              # TODO: Have differenty types of building (docs/main) that can
              # be chosen in a config rather than hacks based on the branch name
              repository = self.repository()
              if repository.branch() is "blog" # HACK
                self.repository().publish(docs, undefined, publishBranch)
              else
                self.repository().publish(Packager.standAlone(pkg, docs), undefined, publishBranch)

        load: (repository) ->
          repository.latestContent()
          .then (results) ->
            self.loadPackage
              repository: cleanRepositoryData repository.toJSON()
              source: processDirectory results

Build the project, returning a promise that will be fulfilled with the `pkg`
when complete.

        build: ->
          data = filetree.data()

          Q(builder.build(data))
          .then (pkg) ->
            config = readSourceConfig(pkg)

            dependencies = config.dependencies or {}

            Packager.collectDependencies(dependencies)
            .then (dependencies) ->
              pkg.dependencies = dependencies

              return pkg

        loadedPackage: loadedPackage

        save: ->
          self.repository().commitTree
            tree: filetree.data()

        dependencies: ->
          loadedPackage().dependencies

        exploreDependency: (name) ->


        loadPackage: (pkg) ->
          loadedPackage pkg

          filetree.load pkg.source

          pkg

        loadFiles: (fileData) ->
          filetree.load fileData

Currently we're exposing the filetree though in the future we shouldn't be.

        filetree: ->
          filetree

        files: ->
          filetree.files()

        fileAt: (path) ->
          self.files().select (file) ->
            file.path() is path
          .first()

        fileContents: (path) ->
          self.fileAt(path)?.content()

        filesMatching: (expr) ->
          self.files().select (file) ->
            file.path().match expr

        writeFile: (path, content) ->
          if existingFile = self.fileAt(path)
            existingFile.content(content)

            return existingFile
          else
            file = File
              path: path
              content: content

            filetree.files.push(file)

            return file

Likewise we shouldn't expose the builder directly either.

        builder: ->
          builder

        config: ->
          readSourceConfig(source: arrayToHash(filetree.data()))

        plugin: (pluginJSON) ->
          self.include require(pluginJSON)

      self.include(Runners)
      self.include(Actions)

      extend require("postmaster")(),
        load: self.loadPackage
        plugin: self.plugin

      return self

Helpers
-------

    {readSourceConfig, arrayToHash} = require("./source/util")

    cleanRepositoryData = (data) ->
      _.pick data, "branch", "default_branch", "full_name", "homepage", "description", "html_url", "url"
