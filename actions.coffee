publish = ({builder, fileData, repository, branch}) ->
  branch ?= "master"
  message = "Built #{branch} in browser in strd6.github.io/tempest"

  if branch is "master"
    path = "index.html"
  else
    path = "#{branch}.html"

  # Assuming git repo with gh-pages branch
  publishBranch = "gh-pages"
  
  builder.build fileData, (build) ->
    # create <ref>.html in gh-pages branch
    repository.writeFile
      path: path
      content: Base64.encode(builder.standAloneHtml(build))
      branch: publishBranch
      message: message

commit = ({fileData, repository, branch, message}) ->
  repository.commitTree
    tree: fileData
    message: message

@Actions =
  save: (params) ->
    commit(params)
      .then ->
        publish(params)

  run: ({builder, filetree}) ->
    builder.build filetree.data(), (build) ->
      if configData = build.source["pixie.json"]?.content
        config = JSON.parse(configData)
      else
        config = {}
      
      sandbox = Sandbox
        width: config.width
        height: config.height
      
      sandbox.document.open()
      sandbox.document.write(builder.standAloneHtml(build))

      sandbox.document.close()

      builder.I.notices? ["Running!"]
      # TODO: Catch and display runtime errors

  load: ({filetree, repository, branch, notices, errors}) ->
    # Decode all content in place
    processDirectory = (items) ->
      items.each (item) ->
        return item unless item.content
        
        item.content = Base64.decode(item.content)
        item.encoding = "raw"
    
    repository.latestTree(branch)
    .then (data) ->
      notices []
      
      treeFiles = data.tree.select (file) ->
        file.type is "blob"
      
      # Gather the data for each file
      async.map treeFiles, (datum, callback) ->
        notices.push "Loading #{datum.url}\n"
        
        Gistquire.api datum.url,
          success: (data) ->
            callback(null, Object.extend(datum, data))
          error: (error) ->
            callback(error)

      , (error, results) ->
        notices ["Radical!"] 
        if error
          errors [error]
          return

        files = processDirectory results
        
        notices ["Loaded!"]
          
        filetree.load files

    .fail (request, status, message) ->
      errors ["Error loading #{owner}/#{repo}: #{message}"]
