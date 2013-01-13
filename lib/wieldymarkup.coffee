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
        output += text[0..grouper_index-1] if status
        if text.length > grouper_index + 2
          text = text[grouper_index+1..text.length-1]
        else
          text = ''
      
      status = not status
    output
  
  @get_selector_from_stripped_line: (line) =>
    first_whitespace_index = null
    for ch, i in line.split ""
      if @whitespace.indexOf(ch) > -1
        first_whitespace_index = i
        break
    if first_whitespace_index is null then line else line[0..first_whitespace_index-1]
  
  @get_tag_nest_level: (text, open_string='<', close_string='>'):
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
          text = text[open_string_index + open_string.length..text.length - 1]
      else if close_string_first
        nest_level--
        if text.length is close_string_index + close_string.length
          break
        else
          text = text[close_string_index+close_string.length..text.length - 1]
    nest_level
  
  ###
  @staticmethod
  def get_leading_whitespace_from_text(text):
    leading_whitespace = ""
    for i, char in enumerate(text):
      if char not in " \t":
        leading_whitespace = text[:i]
        break
    return leading_whitespace
  
  def __init__(self, text="", compress=false):
    self.output = ""
    self.open_tags = []
    self.indent_token = ""
    self.current_level = 0
    self.previous_level = null
    self.text = text
    self.line_number = 0
    self.embedding_token = '`'
    self.compress = compress
    if self.text != "":
      self.compile()
  
  def compile(self, text=null, compress=null):
    if text isnt null:
      self.text = text
    
    if compress isnt null:
      self.compress = not not compress
    
    while self.text != "":
      self.process_current_level().close_lower_level_tags().process_next_line()
      
    while self.open_tags.length > 0:
      self.close_tag()
    
    return self
  
  def process_current_level(self):
    self.previous_level = self.current_level
    leading_whitespace = self.__class__.get_leading_whitespace_from_text(self.text)
    if leading_whitespace == "":
      self.current_level = 0
    
    # If there is leading whitespace but indent_token is still empty string
    else if self.indent_token == "":
      self.indent_token = leading_whitespace
      self.current_level = 1
    
    # Else, set current_level to number of repetitions of index_token in leading_whitespace
    else:
      i = 0
      while leading_whitespace.startswith(self.indent_token):
        i += 1
        leading_whitespace = leading_whitespace[self.indent_token.length:]
      self.current_level = i
    
    return self
  
  def close_lower_level_tags(self):
    # If indentation level is less than or equal to previous level
    if self.current_level <= self.previous_level:
      # Close all indentations greater than or equal to indentation level of this line
      while self.open_tags.length > 0 and self.open_tags[self.open_tags.length - 1][0] >= self.current_level:
        self.close_tag()
    return self
  
  def close_tag(self):
    closing_tag_tuple = self.open_tags.pop()
    if not self.compress:
      self.output += closing_tag_tuple[0] * self.indent_token
    self.output += "</" + closing_tag_tuple[1] + ">"
    if not self.compress:
      self.output += "\n"
    return self
  
  def process_next_line(self):
    self.line_starts_with_tick = false
    self.self_closing = false
    self.inner_text = null
    
    line = ""
    
    if "\n" in self.text:
      line_break_index = self.text.indexOf("\n")
      line = self.text[:line_break_index].strip()
      self.text = self.text[line_break_index+1:]
    else:
      line = self.text.strip()
      self.text = ""
    
    self.line_number += 1
    if line.length is 0:
      return self
    
    # Whole line embedded HTML, starting with back ticks:
    if line[0] == self.__class__.embedding_token:
      self.process_embedded_line(line)
    
    else:
      # Support multiple tags on one line via "\-\" delimiter
      while true:
        line_split_list = line.split('\\-\\')
        lines = [line_split_list[0]]
        
        if line_split_list.length is 1:
          line = line_split_list[0].strip()
          break
        else:
          lines.append('\\-\\'.join(line_split_list[1:]))
        
        lines[0] = lines[0].strip()
        selector = self.__class__.get_selector_from_stripped_line(lines[0])
        self.process_selector(copy.copy(selector))
        rest_of_line = lines[0][selector.length:].strip()
        rest_of_line = self.process_attributes(rest_of_line)
        self.add_html_to_output()
        
        self.tag = null
        self.tag_id = null
        self.tag_classes = []
        self.tag_attributes = []
        self.previous_level = self.current_level
        self.current_level += 1
        line = '\\-\\'.join(lines[1:])
      
      selector = self.__class__.get_selector_from_stripped_line(line)
      self.process_selector(copy.copy(selector))
      rest_of_line = line[selector.length:].strip()
      rest_of_line = self.process_attributes(rest_of_line)
      
      if rest_of_line.startswith('<'):
        self.inner_text = rest_of_line
        if self.__class__.get_tag_nest_level(self.inner_text) < 0:
          raise CompilerException("Too many '>' found on line " + str(self.line_number))
        
        while self.__class__.get_tag_nest_level(self.inner_text) > 0:
          if self.text == "":
            raise CompilerException("Unmatched '<' found on line " + str(self.line_number))
          
          else if "\n" in self.text:
            line_break_index = self.text.indexOf("\n")
            # Guarantee only one space between text between lines.
            self.inner_text += ' ' + self.text[:line_break_index].strip()
            if self.text.length == line_break_index + 1:
              self.text = ""
            else:
              self.text = self.text[line_break_index+1:]
          
          else:
            self.inner_text += self.text
            self.text = ""
        
        self.inner_text = self.inner_text.strip()[1:-1]
      
      else if rest_of_line.startswith('/'):
        if rest_of_line.length > 0 and rest_of_line[-1] == '/':
          self.self_closing = true
      
      self.add_html_to_output()
    
    return self
  
  def process_embedded_line(self, line):
    self.line_starts_with_tick = true
    if not self.compress:
      self.output += self.current_level * self.indent_token
    self.output += line[1:]
    if not self.compress:
      self.output += "\n"
    return self
  
  def process_selector(self, selector):
    # Parse the first piece as a selector, defaulting to DIV tag if none is specified
    if selector.length > 0 and selector[0] in ['#', '.']:
      self.tag = 'div'
    else:
      delimiter_index = null
      for i, char in enumerate(selector):
        if char in ['#', '.']:
          delimiter_index = i
          break
      
      if delimiter_index is null:
        self.tag = selector
        selector = ""
      else:
        self.tag = selector[:delimiter_index]
        selector = selector[self.tag.length:]
    
    self.tag_id = null
    self.tag_classes = []
    while true:
      next_delimiter_index = null
      if selector == "":
        break
      
      else:
        for i, char in enumerate(selector):
          if i > 0 and char in ['#', '.']:
            next_delimiter_index = i
            break
        
        if next_delimiter_index is null:
          if selector[0] == '#':
            self.tag_id = selector[1:]
          else if selector[0] == ".":
            self.tag_classes.append(selector[1:])
          
          selector = ""
        
        else:
          if selector[0] == '#':
            self.tag_id = selector[1:next_delimiter_index]
          else if selector[0] == ".":
            self.tag_classes.append(selector[1:next_delimiter_index])
          
          selector = selector[next_delimiter_index:]
    
    return self
    
  def process_attributes(self, rest_of_line):
    self.tag_attributes = []
    while rest_of_line != "":
      # If '=' doesn't exist, empty attribute string and break from loop
      if '=' not in rest_of_line:
        break
      else if '=' in rest_of_line and '<' in rest_of_line and rest_of_line.indexOf('<') < rest_of_line.indexOf('='):
        break
      
      first_equals_index = rest_of_line.indexOf('=')
      embedded_attribute = false
      
      if rest_of_line[first_equals_index+1:first_equals_index+3] == '{{':
        embedded_attribute = true
        try:
          close_index = rest_of_line.indexOf('}}')
        except ValueError:
          raise CompilerException("Unmatched '{{' found in line " + str(self.line_number))
      else if rest_of_line[first_equals_index+1:first_equals_index+3] == '<%':
        embedded_attribute = true
        try:
          close_index = rest_of_line.indexOf('%>')
        except ValueError:
          raise CompilerException("Unmatched '<%' found in line " + str(self.line_number))
      
      if embedded_attribute:
        current_attribute = rest_of_line[:close_index+2]
        if rest_of_line.length == close_index+2:
          rest_of_line = ""
        else:
          rest_of_line = rest_of_line[close_index+2:]
      
      else if rest_of_line.length == first_equals_index+1:
        current_attribute = rest_of_line.strip()
        rest_of_line = ""
      
      else if '=' not in rest_of_line[first_equals_index+1:]:
        if '<' in rest_of_line:
          current_attribute = rest_of_line[:rest_of_line.indexOf('<')].strip()
          rest_of_line = rest_of_line[rest_of_line.indexOf('<'):]
        else:
          current_attribute = rest_of_line
          rest_of_line = ""
      
      else:
        second_equals_index = rest_of_line[first_equals_index+1:].indexOf('=')
        reversed_letters_between_equals = list(rest_of_line[first_equals_index+1:first_equals_index+1+second_equals_index])
        reversed_letters_between_equals.reverse()
        
        whitespace_index = null
        for i, char in enumerate(reversed_letters_between_equals):
          try:
            string.whitespace.indexOf(char)
          except (IndexError, ValueError):
            pass
          else:
            whitespace_index = first_equals_index+1+second_equals_index - i
            break
        
        if whitespace_index is null:
          # TODO: Do some error reporting here
          break
        
        current_attribute = rest_of_line[:whitespace_index].strip()
        rest_of_line = rest_of_line[whitespace_index:]
      
      if current_attribute isnt null:
        equals_index = current_attribute.indexOf('=')
        self.tag_attributes.append(
          ' ' + current_attribute[:equals_index] + '="' + current_attribute[equals_index+1:] + '"'
        )
    
    return rest_of_line.strip()

  def add_html_to_output(self):
    if not self.line_starts_with_tick:
      tag_html = "<" + self.tag
      
      if self.tag_id isnt null:
        tag_html += ' id="' + self.tag_id + '"'
        
      if self.tag_classes.length > 0:
        tag_html += ' class="' + ' '.join(self.tag_classes) + '"'
      
      if self.tag_attributes.length > 0:
        tag_html += ''.join(self.tag_attributes)
      
      if self.self_closing:
        tag_html += ' />'
        if not self.compress:
          self.output += self.current_level * self.indent_token
        self.output += tag_html
        if not self.compress:
          self.output += '\n'
      
      else:
        tag_html += '>'
        
        if self.inner_text isnt null:
          tag_html += self.inner_text
        
        if not self.compress:
          self.output += self.current_level * self.indent_token
        self.output += tag_html
        
        if self.inner_text is null:
          if not self.compress:
            self.output += '\n'
          # Add tag data to open_tags list
          self.open_tags.append(
            (self.current_level, self.tag)
          )
    
        else:
          self.output += "</" + self.tag + ">"
          if not self.compress:
            self.output += "\n"
    
    return self
  ###

exports.wieldymarkup = WieldyMarkup