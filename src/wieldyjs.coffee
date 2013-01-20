_ = require 'underscore'
_.str = require 'underscore.string'

class WieldyJS
  
  @whitespace: " \t"
  
  ###
  Removes all substrings surrounded by a grouping substring, including
    grouping substring on both sides.
  
  @param <String> text - The string from which to remove grouped substrings
  @param <String> z - The grouping substring
  @return <String> - The string with substrings removed
  ###
  @removeGroupedText: (text, groupingToken) =>
    output = ""
    status = true
    while text isnt ''
      groupingTokenIndex = text.indexOf groupingToken
      if groupingTokenIndex is -1
        output += text if status
        text = ''
      else
        output += text.substring(0, groupingTokenIndex) if status
        if text.length > groupingTokenIndex + 2
          text = text.substring(groupingTokenIndex+1, text.length)
        else
          text = ''
      status = not status
    output
  
  ###
  Gets the selector from the line of markup
  
  @param <String> line - The string from which to get the selector
  @return <String> selector - The substring from the beginning of the line until the
    first whitespace character
  ###
  @getSelectorFromLine: (line) =>
    selector = line
    firstWhitespaceIndex = -1
    for ch, i in line.split ""
      if @whitespace.indexOf(ch) > -1
        firstWhitespaceIndex = i
        break
    if firstWhitespaceIndex > -1
      selector = selector.substring(0, firstWhitespaceIndex)
    selector
  
  ###
  Determines the level of nesting in a string
  
  @param <String> text - The string in which to determine the nest level
  @param <String> openString - The substring that denotes an increase in
    nesting level.
  @param <String> closeString - The substring that denotes a decrase in
    nesting level.
  @return <String> nestLevel - The substring from the beginning of the line
    until the first whitespace character
  ###
  @getTagNestLevel: (text, openString = '<', closeString = '>') =>
    nestLevel = 0
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
        nestLevel++
        if text.length is openStringIndex + openString.length
          break
        else
          text = text.substring(
            openStringIndex + openString.length, text.length
          )
      else if closeStringFirst
        nestLevel--
        if text.length is closeStringIndex + closeString.length
          break
        else
          text = text.substring(
            closeStringIndex+closeString.length, text.length
          )
    nestLevel
  
  ###
  Gets the string of leading spaces and tabs in some text.
  
  @param <String> text - The string from which to get the leading whitespace
  @return <String> leadingWhitespace - The leading whitespace in the string
  ###
  @getLeadingWhitespaceFromText: (text) =>
    leadingWhitespace = ""
    for ch, i in text.split ""
      if @whitespace.indexOf(ch) is -1
        leadingWhitespace = text.substring 0, i
        break
    leadingWhitespace
  
  ###
  Instantiate a new Compiler instance. Automatically compiles text if passed
    in via parameters.
  
  @param <String> text - The input text to compile
  @param <Boolean> compress - Whether to leave whitespace between HTML tags or not
  ###
  constructor: (text = "", compress = false) ->
    @text = text
    @compress = compress
    @compile()
  
  ###
  Compiles input markup into HTML.
  
  @param <String> text - The input text to compile
  @param <Boolean> compress - Whether to leave whitespace between HTML tags or not
  @return <String> The compiled HTML
  ###
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
    @output
  
  ###
  Determines current nesting level for HTML output.
  
  @return <Object> this - The reference to this instance object.
  ###
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
  
  ###
  Iterates through nesting levels that have been closed.
  
  @return <Object> this - The reference to this instance object.
  ###
  closeLowerLevelTags: =>
    if @currentLevel <= @previousLevel
      while @openTags.length > 0 and
      @openTags[@openTags.length - 1][0] >= @currentLevel
        @closeTag()
    @
  
  ###
  Adds closing HTML tags to output and removes entry from @openTags.
  
  @return <Object> this - The reference to this instance object.
  ###
  closeTag: =>
    closingTagArray = @openTags.pop()
    if not @compress and closingTagArray[0] > 0
      @output += _.str.repeat @indentToken, closingTagArray[0]
    @output += "</#{closingTagArray[1]}>"
    if not @compress
      @output += "\n"
    @
  
  ###
  Gets the next line of text, splits it into relevant pieces, and sends them
    to respective methods for parsing.
  
  @return <Object> this - The reference to this instance object.
  ###
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
  
  ###
  Adds an embedded line to output, removing @embedding_token
    and not compiling.
  
  @param <String> line - The line of text with @embedding_token
  @return <Object> this - The reference to this instance object.
  ###
  processEmbeddedLine: (line) =>
    @lineStartsWithTick = true
    if not @compress
      @output += _.str.repeat @indentToken, @currentLevel
    @output += _.str.trim(line).substr 1
    if not @compress
      @output += "\n"
    @
  
  ###
  Parses a selector into tag, ID, and classes.
  
  @param <String> selector - The unparsed selector string
  @return <Object> this - The reference to this instance object.
  ###
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
  
  ###
  Parses attribute string off of the beginning of a line of text after
    the selector was removed, and returns everything after the attribute
    string.
  
  @param <String> rest_of_line - The line of text after leading whitespace and selector have been removed
  @return <String> this - The input text after all attributes have been removed
  ###
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
  
  ###
  Adds HTML to output for a given line.
  
  @return <Object> this - The reference to this instance object.
  ###
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
  Compiler: WieldyJS
