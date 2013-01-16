_ = require 'underscore'
_.str = require 'underscore.string'

class WieldyMarkup
  
  @whitespace: " \t"
  
  @removeGroupedText: (text, z) =>
    output = ""
    status = true
    while text isnt ''
      grouperIndex = text.indexOf z
      if grouperIndex is -1
        output += text if status
        text = ''
      else
        output += text.substring(0, grouperIndex) if status
        if text.length > grouperIndex + 2
          text = text.substring(grouperIndex+1, text.length)
        else
          text = ''
      status = not status
    output
  
  @getSelectorFromLine: (line) =>
    firstWhitespaceIndex = null
    for ch, i in line.split ""
      if @whitespace.indexOf(ch) > -1
        firstWhitespaceIndex = i
        break
    if firstWhitespaceIndex is null
      line
    else
      line.substring(0, firstWhitespaceIndex)
  
  @getTagNestLevel: (text, openString = '<', closeString = '>') =>
    nest_level = 0
    while true
      openStringIndex = text.indexOf openString
      closeStringIndex = text.indexOf closeString
      openStringFirst = false
      closeStringFirst = false
      
      if openStringIndex is -1 and closeStringIndex is -1
        break
      else if openStringIndex isnt -1
        openStringFirst = true
      else if closeStringIndex isnt -1
        closeStringFirst = true
      else
        if openStringIndex < closeStringIndex
          openStringFirst = true
        else
          closeStringFirst = true
      
      if openStringFirst
        nest_level++
        if text.length is openStringIndex + openString.length
          break
        else
          text = text.substring(
            openStringIndex + openString.length, text.length
          )
      else if closeStringFirst
        nest_level--
        if text.length is closeStringIndex + closeString.length
          break
        else
          text = text.substring(
            closeStringIndex+closeString.length, text.length
          )
    nest_level
  
  @getLeadingWhitespaceFromText: (text) =>
    leadingWhitespace = ""
    for ch, i in text.split ""
      if @whitespace.indexOf(ch) is -1
        leadingWhitespace = text.substring 0, i
        break
    leadingWhitespace
  
  constructor: (text = "", compress = false) ->
    @text = text
    @compress = compress
    @compile()
  
  compile: (text = null, compress = null) ->
    @text = text if text isnt null
    @compress = not not compress if compress isnt null
    @output = ""
    @openTags = []
    @indentToken = ""
    @currentLevel = 0
    @previousLevel = null
    @lineNumber = 0
    @embeddingToken = '`'
    
    while @text isnt ""
      @processCurrentLevel().closeLowerLevelTags().processNextLine()
      
    @closeTag() while @openTags.length > 0
    @
  
  processCurrentLevel: =>
    @previousLevel = @currentLevel
    leadingWhitespace = @constructor.getLeadingWhitespaceFromText @text
    
    if leadingWhitespace is ""
      @currentLevel = 0
    else if @indentToken is ""
      @indentToken = leadingWhitespace
      @currentLevel = 1
    else
      i = 0
      while _.str.startsWith leadingWhitespace, @indentToken
        leadingWhitespace = leadingWhitespace.substring(
          @indentToken.length, leadingWhitespace.length
        )
        i += 1
      @currentLevel = i
    @
  
  closeLowerLevelTags: =>
    if @currentLevel <= @previousLevel
      while @openTags.length > 0 and
      @openTags[@openTags.length - 1][0] >= @currentLevel
        @closeTag()
    @
  
  closeTag: =>
    closingTagArray = @openTags.pop()
    if not @compress and closingTagArray[0] > 0
      @output += _.str.repeat @indentToken, closingTagArray[0]
    @output += "</#{closingTagArray[1]}>"
    if not @compress
      @output += "\n"
    @
  
  processNextLine: =>
    @lineStartsWithTick = false
    @selfClosing = false
    @innerText = null
    line = ""
    
    if "\n" in @text
      lineBreakIndex = @text.indexOf "\n"
      line = _.str.trim @text.substring 0, lineBreakIndex
      @text = @text.substring lineBreakIndex+1, @text.length
    else
      line = _.str.trim @text
      @text = ""
    
    @lineNumber += 1
    if line.length is 0
      return @
    
    if line[0] is @embeddingToken
      @processEmbeddedLine line
    else
      lineSplitList = line.split '\\-\\'
      while lineSplitList.length > 1
        temp_line = _.str.trim lineSplitList.shift()
        selector = @constructor.getSelectorFromLine temp_line
        @processSelector selector
        restOfLine = _.str.trim(
          temp_line.substring selector.length, temp_line.length
        )
        restOfLine = @processAttributes restOfLine
        @addHtmlToOutput()
        
        @tag = null
        @tagId = null
        @tagClasses = []
        @tagAttributes = []
        @previousLevel = @currentLevel
        @currentLevel++
      
      line = _.str.trim lineSplitList[lineSplitList.length - 1]
      selector = @constructor.getSelectorFromLine line
      @processSelector selector
      restOfLine = _.str.trim line.substring selector.length, line.length
      restOfLine = @processAttributes restOfLine
      
      if _.str.startsWith restOfLine, '<'
        @innerText = restOfLine
        if @constructor.getTagNestLevel(@innerText) < 0
          throw "Too many '>' found on line #{@lineNumber}"
        
        while @constructor.getTagNestLevel(@innerText) > 0
          if @text is ""
            throw "Unmatched '<' found on line #{@lineNumber}"
          else if "\n" in @text
            lineBreakIndex = @text.indexOf "\n"
            # Guarantee only one space between text between lines.
            @innerText += ' ' + _.str.trim @text.substring 0, lineBreakIndex
            if @text.length is lineBreakIndex + 1
              @text = ""
            else
              @text = @text.substring lineBreakIndex+1, @text.length
          else
            @innerText += @text
            @text = ""
        @innerText = _.str.trim(@innerText).substring 1, @innerText.length - 1
      else if _.str.startsWith restOfLine, '/'
        if restOfLine.length > 0 and restOfLine[restOfLine.length - 1] is '/'
          @selfClosing = true
      
      @addHtmlToOutput()
    @
  
  processEmbeddedLine: (line) =>
    @lineStartsWithTick = true
    if not @compress
      @output += _.str.repeat @indentToken, @currentLeve
    @output += line.substring 1, line.length
    if not @compress
      @output += "\n"
    @
  
  processSelector: (selector) =>
    if selector.length > 0 and selector[0] in ['#', '.']
      @tag = 'div'
    else
      delimiterIndex = null
      for ch, i in selector.split ""
        if ch in ['#', '.']
          delimiterIndex = i
          break
      
      if delimiterIndex is null
        @tag = selector
        selector = ""
      else
        @tag = selector.substring 0, delimiterIndex
        selector = selector.substring @tag.length, selector.length
    
    @tagId = null
    @tagClasses = []
    while true
      nextDelimiterIndex = null
      if selector is ""
        break
      
      else
        for ch, i in selector
          if i > 0 and ch in ['#', '.']
            nextDelimiterIndex = i
            break
        
        if nextDelimiterIndex is null
          if selector[0] is '#'
            @tagId = selector.substring 1, selector.length
          else if selector[0] is "."
            @tagClasses.push selector.substring 1, selector.length
          
          selector = ""
        
        else
          if selector[0] is '#'
            @tagId = selector.substring 1, nextDelimiterIndex
          else if selector[0] is "."
            @tagClasses.push selector.substring 1, nextDelimiterIndex
          
          selector = selector.substring nextDelimiterIndex, selector.length
    @
    
  processAttributes: (restOfLine) =>
    @tagAttributes = []
    while restOfLine isnt ""
      if '=' not in restOfLine
        break
      else if '=' in restOfLine and '<' in restOfLine and
      restOfLine.indexOf('<') < restOfLine.indexOf('=')
        break
      
      firstEqualsIndex = restOfLine.indexOf '='
      embeddedAttribute = false
      
      if restOfLine.substr(firstEqualsIndex+1, 2) is '{{'
        embeddedAttribute = true
        closeIndex = restOfLine.indexOf '}}'
        if closeIndex is -1
          throw "Unmatched '{{' found in line #{@lineNumber}"
      else if restOfLine.substr(firstEqualsIndex+1, 2) is '<%'
        embeddedAttribute = true
        closeIndex = restOfLine.indexOf '%>'
        if closeIndex is -1
          throw "Unmatched '<%' found in line #{@lineNumber}"
      
      if embeddedAttribute
        currentAttribute = restOfLine.substring 0, closeIndex+2
        if restOfLine.length is closeIndex+2
          restOfLine = ""
        else
          restOfLine = restOfLine.substr closeIndex+2
      else if restOfLine.length is firstEqualsIndex+1
        currentAttribute = _.str.trim restOfLine
        restOfLine = ""
      else if '=' not in restOfLine.substr(firstEqualsIndex+1)
        if '<' in restOfLine
          currentAttribute = _.str.trim(
            restOfLine.substring 0, restOfLine.indexOf '<'
          )
          restOfLine = restOfLine.substr restOfLine.indexOf '<'
        else
          currentAttribute = restOfLine
          restOfLine = ""
      else
        secondEqualsIndex = restOfLine.substr(firstEqualsIndex+1).indexOf '='
        reversedLettersBetweenEquals = _.str.reverse restOfLine.substring(
          firstEqualsIndex+1, firstEqualsIndex+1+secondEqualsIndex
        )
        
        whitespaceIndex = null
        for ch, i in reversedLettersBetweenEquals
          if " \t".indexOf(ch) > -1
            whitespaceIndex = firstEqualsIndex + 1 + secondEqualsIndex - i
            break
        
        if whitespaceIndex is null
          # TODO: Do some error reporting here
          break
        
        currentAttribute = _.str.trim restOfLine.substring 0, whitespaceIndex
        restOfLine = restOfLine.substr whitespaceIndex
      
      if currentAttribute isnt null
        equalsIndex = currentAttribute.indexOf '='
        @tagAttributes.push(
          " #{currentAttribute.substring(0, equalsIndex)}=" +
          "#{('"' + currentAttribute.substr(equalsIndex+1) + '"')}"
        )
    
    _.str.trim restOfLine

  addHtmlToOutput: =>
    if not @lineStartsWithTick
      tagHtml = "<#{@tag}"
      tagHtml += " id=\"" + @tagId + "\"" if @tagId isnt null
        
      if @tagClasses.length > 0
        tagHtml += " class=\"" + @tagClasses.join(' ') + "\""
      
      tagHtml += @tagAttributes.join '' if @tagAttributes.length > 0
      
      if @selfClosing
        tagHtml += " />"
        if not @compress
          @output += _.str.repeat(@indentToken, @currentLevel)
        @output += tagHtml
        if not @compress
          @output += "\n"
      else
        tagHtml += ">"
        if @innerText isnt null
          tagHtml += @innerText
        
        if not @compress
          @output += _.str.repeat(@indentToken, @currentLevel)
        @output += tagHtml
        
        if @innerText is null
          @output += "\n" if not @compress
          # Add tag data to openTags list
          @openTags.push(
            [@currentLevel, @tag]
          )
        else
          @output += "</#{@tag}>"
          @output += "\n" if not @compress
    
    @

exports = module.exports =
  version: '0.2.1'
  Compiler: WieldyMarkup
