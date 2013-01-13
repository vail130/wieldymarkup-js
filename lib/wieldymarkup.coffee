_ = require 'underscore'
_.str = require 'underscore.string'

class WieldyMarkup
  
  @whitespace: " \t"
  
  @remove_grouped_text: (text, z) =>
    output = ""
    status = true
    while text_copy isnt ''
      grouper_index = text.indexOf z
      if grouper_index is -1
        output += text if status
        text = ''
      
      else
        output += text.substring(0, grouper_index) if status
        if text.length > grouper_index + 2
          text = text.substring(grouper_index+1, text.length)
        else
          text = ''
      
      status = not status
    output
  
  @get_selector_from_line: (line) =>
    first_whitespace_index = null
    for ch, i in line.split ""
      if @whitespace.indexOf(ch) > -1
        first_whitespace_index = i
        break
    if first_whitespace_index is null then line else line.substring(0, first_whitespace_index)
  
  @get_tag_nest_level: (text, open_string='<', close_string='>') =>
    nest_level = 0
    while true
      open_string_index = if text.indexOf(open_string) > -1 then text.indexOf(open_string) else null
      close_string_index = if text.indexOf(close_string) > -1 then text.indexOf(close_string) else null
      open_string_first = false
      close_string_first = false
      
      # Only same if both null
      if open_string_index is close_string_index
        break
      else if open_string_index isnt null
        open_string_first = true
      else if close_string_index isnt null
        close_string_first = true
      else
        if open_string_index < close_string_index
          open_string_first = true
        else
          close_string_first = true
      
      if open_string_first
        nest_level++
        if text.length is open_string_index + open_string.length
          break
        else
          text = text.substring(open_string_index + open_string.length, text.length)
      else if close_string_first
        nest_level--
        if text.length is close_string_index + close_string.length
          break
        else
          text = text.substring(close_string_index+close_string.length, text.length)
    nest_level
  
  @get_leading_whitespace_from_text: (text) =>
    leading_whitespace = ""
    for ch, i in text.split ""
      if @whitespace.indexOf(ch) is -1
        leading_whitespace = text.substring 0, i
        break
    leading_whitespace
  
  constructor: (text="", compress=false) ->
    @text = text
    @compress = compress
    @compile() if @text isnt ""
  
  compile: (text=null, compress=null) =>
    @text = text if text isnt null
    @compress = not not compress if compress isnt null
    
    @output = ""
    @open_tags = []
    @indent_token = ""
    @current_level = 0
    @previous_level = null
    @line_number = 0
    @embedding_token = '`'
    
    while @text isnt ""
      @process_current_level().close_lower_level_tags().process_next_line()
      
    @close_tag() while @open_tags.length > 0
    @
  
  process_current_level: =>
    @previous_level = @current_level
    leading_whitespace = @::get_leading_whitespace_from_text @text
    if leading_whitespace is ""
      @current_level = 0
    
    # If there is leading whitespace but indent_token is still empty string
    else if @indent_token is ""
      @indent_token = leading_whitespace
      @current_level = 1
    
    # Else, set current_level to number of repetitions of index_token in leading_whitespace
    else
      i = 0
      while _.str.startsWith leading_whitespace, @indent_token
        leading_whitespace = leading_whitespace.substring @indent_token.length, leading_whitespace.length
        i += 1
      @current_level = i
    
    @
  
  close_lower_level_tags: =>
    # If indentation level is less than or equal to previous level
    if @current_level <= @previous_level
      # Close all indentations greater than or equal to indentation level of this line
      while @open_tags.length > 0 and @open_tags[@open_tags.length - 1][0] >= @current_level
        @close_tag()
    @
  
  close_tag: =>
    closing_tag_tuple = @open_tags.pop()
    if not @compress
      output += _.str.repeat @indent_token, closing_tag_tuple[0]
    @output += "</" + closing_tag_tuple[1] + ">"
    @output += "\n" if not @compress
    @
  
  process_next_line: =>
    @line_starts_with_tick = false
    @self_closing = false
    @inner_text = null
    line = ""
    
    if @text.indexOf("\n") > -1
      line_break_index = @text.indexOf "\n"
      line = _.str.trim @text.substring 0, line_break_index
      @text = @text.substring line_break_index+1, @text.length
    else
      line = _.str.trim @text
      @text = ""
    
    @line_number += 1
    if line.length is 0
      return @
    
    # Whole line embedded HTML, starting with back ticks:
    if line[0] is @embedding_token
      @process_embedded_line line
    
    else
      # Support multiple tags on one line via "\-\" delimiter
      while true
        line_split_list = line.split '\\-\\'
        lines = [line_split_list[0]]
        
        if line_split_list.length is 1
          line = _.str.trim line_split_list[0]
          break
        else
          lines.push _.str.join '\\-\\', line_split_list.substring(1, line_split_list.length)
        
        lines[0] = _.str.trim lines[0]
        selector = @::get_selector_from_line lines[0]
        @process_selector selector
        rest_of_line = _.str.trim lines[0].substring selector.length, lines[0].length
        rest_of_line = @process_attributes rest_of_line
        @add_html_to_output()
        
        @tag = null
        @tag_id = null
        @tag_classes = []
        @tag_attributes = []
        @previous_level = @current_level
        @current_level++
        line = _.str.join '\\-\\', lines.substring 1, lines.length
      
      selector = @::get_selector_from_line line
      @process_selector selector
      rest_of_line = _.str.trim line.substring selector.length, line.length
      rest_of_line = @process_attributes rest_of_line
      
      if _.str.startsWith rest_of_line, '<'
        @inner_text = rest_of_line
        if @::get_tag_nest_level(@inner_text) < 0
          throw "Too many '>' found on line #{@line_number}"
        
        while @::get_tag_nest_level(@inner_text) > 0
          if @text is ""
            throw "Unmatched '<' found on line #{@line_number}"
          
          else if "\n" in @text
            line_break_index = @text.indexOf "\n"
            # Guarantee only one space between text between lines.
            @inner_text += ' ' + _.str.trim @text.substring 0, line_break_index
            if @text.length is line_break_index + 1
              @text = ""
            else
              @text = @text.substring line_break_index+1, @text.length
          
          else
            @inner_text += @text
            @text = ""
        
        @inner_text = _.str.trim(@inner_text).substring 1, @inner_text.length - 1
      
      else if _.str.startsWith rest_of_line, '/'
        if rest_of_line.length > 0 and rest_of_line[rest_of_line.length - 1] is '/'
          @self_closing = true
      
      @add_html_to_output()
    @
  
  process_embedded_line: (line) =>
    @line_starts_with_tick = true
    @output += _.str.repeat @indent_token, @current_level if not @compress
    @output += line.substring 1, line.length
    @output += "\n" if not @compress
    @
  
  process_selector: (selector) =>
    # Parse the first piece as a selector, defaulting to DIV tag if none is specified
    if selector.length > 0 and selector[0] in ['#', '.']
      @tag = 'div'
    else
      delimiter_index = null
      for ch, i in selector.split ""
        if ch in ['#', '.']
          delimiter_index = i
          break
      
      if delimiter_index is null
        @tag = selector
        selector = ""
      else
        @tag = selector.substring 0, delimiter_index
        selector = selector.substring @tag.length, selector.length
    
    @tag_id = null
    @tag_classes = []
    while true
      next_delimiter_index = null
      if selector is ""
        break
      
      else
        for ch, i in selector
          if i > 0 and ch in ['#', '.']
            next_delimiter_index = i
            break
        
        if next_delimiter_index is null
          if selector[0] is '#'
            @tag_id = selector.substring 1, selector.length
          else if selector[0] is "."
            @tag_classes.push selector.substring 1, selector.length
          
          selector = ""
        
        else
          if selector[0] is '#'
            @tag_id = selector.substring 1, next_delimiter_index
          else if selector[0] is "."
            @tag_classes.push selector.substring 1, next_delimiter_index
          
          selector = selector.substring next_delimiter_index, selector.length
    @
    
  process_attributes: (rest_of_line) =>
    @tag_attributes = []
    while rest_of_line isnt ""
      # If '=' doesn't exist, empty attribute string and break from loop
      if '=' not in rest_of_line
        break
      
      # End line with "and" for coffeescript compiler
      else if '=' in rest_of_line and '<' in rest_of_line and
      rest_of_line.indexOf('<') < rest_of_line.indexOf('=')
        break
      
      first_equals_index = rest_of_line.indexOf '='
      embedded_attribute = false
      
      if rest_of_line.substr(first_equals_index+1, 2) is '{{'
        embedded_attribute = true
        close_index = rest_of_line.indexOf '}}'
        if close_index is -1
          throw "Unmatched '{{' found in line #{@line_number}"
      
      else if rest_of_line.substr(first_equals_index+1, 2) is '<%'
        embedded_attribute = true
        close_index = rest_of_line.indexOf '%>'
        if close_index is -1
          throw "Unmatched '<%' found in line #{@line_number}"
      
      if embedded_attribute
        current_attribute = rest_of_line.substring 0, close_index+2
        if rest_of_line.length is close_index+2
          rest_of_line = ""
        else
          rest_of_line = rest_of_line.substr close_index+2
      
      else if rest_of_line.length is first_equals_index+1
        current_attribute = _.str.trim rest_of_line
        rest_of_line = ""
      
      else if '=' not in rest_of_line.substr(first_equals_index+1)
        if '<' in rest_of_line
          current_attribute = _.str.trim rest_of_line.substring 0, rest_of_line.indexOf '<'
          rest_of_line = rest_of_line.substr rest_of_line.indexOf '<'
        else
          current_attribute = rest_of_line
          rest_of_line = ""
      
      else
        second_equals_index = rest_of_line.substr(first_equals_index+1).indexOf '='
        reversed_letters_between_equals = _.str.reverse rest_of_line.substring(
          first_equals_index+1, first_equals_index+1+second_equals_index
        )
        
        whitespace_index = null
        for ch, i in reversed_letters_between_equals
          if " \t".indexOf(ch) > -1
            whitespace_index = first_equals_index + 1 + second_equals_index - i
            break
        
        if whitespace_index is null
          # TODO: Do some error reporting here
          break
        
        current_attribute = _.str.trim rest_of_line.substring 0, whitespace_index
        rest_of_line = rest_of_line.substr whitespace_index
      
      if current_attribute isnt null
        equals_index = current_attribute.indexOf '='
        @tag_attributes.push(
          " #{current_attribute.substring(0, equals_index)}=" +
          "#{('"' + current_attribute.substr(equals_index+1) + '"')}"
        )
    
    _.str.trim rest_of_line

  add_html_to_output: =>
    if not @line_starts_with_tick
      tag_html = "<" + @tag
      tag_html += ' id="' + @tag_id + '"' if @tag_id isnt null
        
      if @tag_classes.length > 0
        tag_html += ' class="' + @tag_classes.join(' ') + '"'
      
      tag_html += @tag_attributes.join '' if @tag_attributes.length > 0
      
      if @self_closing
        tag_html += ' />'
        @output += _.str.repeat(@indent_token, @current_level) if not @compress
        @output += tag_html
        @output += "\n" if not @compress
      
      else
        tag_html += '>'
        tag_html += @inner_text if @inner_text isnt null
        
        @output += _.str.repeat(@indent_token, @current_level) if not @compress
        @output += tag_html
        
        if @inner_text is null
          @output += "\n" if not @compress
          # Add tag data to open_tags list
          @open_tags.push(
            [@current_level, @tag]
          )
    
        else
          @output += "</" + @tag + ">"
          @output += "\n" if not @compress
    
    @

exports.wieldymarkup = WieldyMarkup