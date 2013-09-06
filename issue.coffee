@Issue = (I={}) ->
  self = Model(I)

  self.extend
    optionText: ->
      "#{I.number} - #{I.title}"
    
    fullDescription: ->
      """
        #{self.optionText()}
        #{I.html_url}
        #{I.body}
      """

  return self
