expect = require('chai').expect
Compiler = require('../lib/wieldymarkup').Compiler

describe 'Compiler', ->
  
  describe '#removeGroupedText()', ->
    it 'should return text with substrings surrounded by the second parameter removed', ->
      sample = "The cat ran 'into the big 'home!"
      expect(Compiler.removeGroupedText sample, "'").to.equal "The cat ran home!"
      
      sample = "The cat ran 'into the big home!"
      expect(Compiler.removeGroupedText sample, "'").to.equal "The cat ran "
      
      sample = "The cat ran `into the big `home!"
      expect(Compiler.removeGroupedText sample, "`").to.equal "The cat ran home!"
  
  describe '#getSelectorFromLine()', ->
    it 'should return the selector string from a line', ->
    line = "div.class#id data-val=val data-val2=<%= val2 %> <Content <i>haya!</i> goes here>"
    expect(Compiler.getSelectorFromLine line).to.equal "div.class#id"
    
    line = "div"
    expect(Compiler.getSelectorFromLine line).to.equal "div"
    
    line = ".class#id.class2 val=val1"
    expect(Compiler.getSelectorFromLine line).to.equal ".class#id.class2"
  
  
  
  ###
  def test_get_tag_nest_level(self):
    text = "  <div>"
    self.assertEqual(Compiler.get_tag_nest_level(text), 0)
    
    text = "  <div <la;sdfajsd;f> dfajsl;fadfl   >"
    self.assertEqual(Compiler.get_tag_nest_level(text), 0)
    
    text = "  <div <la;sdfajsd;f dfajsl;fadfl   >"
    self.assertEqual(Compiler.get_tag_nest_level(text), 1)
    
    text = "  <div la;sdfajsd;f> dfajsl;fadfl   >"
    self.assertEqual(Compiler.get_tag_nest_level(text), -1)
    
    text = "  {{div {{la;sdfajsd;f}} dfajsl;fadfl   }}"
    self.assertEqual(Compiler.get_tag_nest_level(text, '{{', '}}'), 0)
  
  def test_get_leading_whitespace_from_text(self):
    line = "    `<div class='class' id='id'>Content goes here</div>"
    self.assertEqual(Compiler.get_leading_whitespace_from_text(line), "    ")
    
    line = "\t\tdiv.class#id data-val=val data-val2=<%= val2 %> <Content <i>haya!</i> goes here>"
    self.assertEqual(Compiler.get_leading_whitespace_from_text(line), "\t\t")
    
    line = "\n  div.class#id data-val=val data-val2=<%= val2 %> <Content <i>haya!</i> goes here>"
    self.assertEqual(Compiler.get_leading_whitespace_from_text(line), "")
  
  def test_init_values(self):
    c = Compiler()
    comparison_values = [
      ('output', ''),
      ('open_tags', []),
      ('indent_token', ''),
      ('current_level', 0),
      ('previous_level', None),
      ('text', ''),
      ('line_number', 0),
      ('compress', False),
    ]
    
    for cv in comparison_values:
      self.assertEqual(getattr(c, cv[0]), cv[1])
  
  def test_process_current_level(self):
    c = Compiler()
    c.text = "    div"
    c.process_current_level()
    self.assertEqual(c.previous_level, 0)
    self.assertEqual(c.current_level, 1)
    self.assertEqual(c.indent_token, "    ")
    
    c = Compiler()
    c.text = "    div"
    c.indent_token = "  "
    c.process_current_level()
    self.assertEqual(c.previous_level, 0)
    self.assertEqual(c.current_level, 2)
    self.assertEqual(c.indent_token, "  ")
    
    c = Compiler()
    c.text = "\t\tdiv"
    c.indent_token = "\t"
    c.process_current_level()
    self.assertEqual(c.previous_level, 0)
    self.assertEqual(c.current_level, 2)
    self.assertEqual(c.indent_token, "\t")
    
  def test_close_tag(self):
    c = Compiler()
    c.indent_token = "  "
    c.open_tags = [(0, "div")]
    c.close_tag()
    self.assertEqual(c.output, "</div>\n")
    self.assertEqual(c.open_tags, [])
    
    c = Compiler('', compress=True)
    c.indent_token = "  "
    c.open_tags = [(0, "div")]
    c.close_tag()
    self.assertEqual(c.output, "</div>")
    self.assertEqual(c.open_tags, [])
  
  def test_close_lower_level_tags(self):
    c = Compiler()
    c.current_level = 0
    c.previous_level = 2
    c.indent_token = "  "
    c.open_tags = [
      (0, "div"),
      (1, "div"),
      (2, "span"),
    ]
    c.close_lower_level_tags()
    self.assertEqual(c.output, "    </span>\n  </div>\n</div>\n")
    
    c = Compiler('', compress=True)
    c.current_level = 0
    c.previous_level = 2
    c.indent_token = "  "
    c.open_tags = [
      (0, "div"),
      (1, "div"),
      (2, "span"),
    ]
    c.close_lower_level_tags()
    self.assertEqual(c.output, "</span></div></div>")
  
  def test_process_embedded_line(self):
    c = Compiler()
    c.current_level = 2
    c.indent_token = "  "
    c.process_embedded_line("`<div>")
    self.assertEqual(c.output, "    <div>\n")
    
    c = Compiler()
    c.current_level = 3
    c.indent_token = "\t"
    c.process_embedded_line("`<div>")
    self.assertEqual(c.output, "\t\t\t<div>\n")
    
    c = Compiler('', compress=True)
    c.current_level = 3
    c.indent_token = "\t"
    c.process_embedded_line("`<div>")
    self.assertEqual(c.output, "<div>")
  
  def test_process_selector(self):
    c = Compiler()
    c.process_selector("div")
    self.assertEqual(c.tag, "div")
    self.assertEqual(c.tag_id, None)
    self.assertEqual(c.tag_classes, [])
    
    c = Compiler()
    c.process_selector("span.class1#id.class2")
    self.assertEqual(c.tag, "span")
    self.assertEqual(c.tag_id, "id")
    self.assertEqual(c.tag_classes, ["class1", "class2"])
    
    c = Compiler()
    c.process_selector("#id.class")
    self.assertEqual(c.tag, "div")
    self.assertEqual(c.tag_id, "id")
    self.assertEqual(c.tag_classes, ["class"])
  
  def test_process_attributes(self):
    c = Compiler()
    rest_of_line = c.process_attributes("")
    self.assertEqual(c.tag_attributes, [])
    self.assertEqual(rest_of_line, "")
    
    c = Compiler()
    rest_of_line = c.process_attributes("href=# target=_blank")
    self.assertEqual(c.tag_attributes, [' href="#"', ' target="_blank"'])
    self.assertEqual(rest_of_line, "")
    
    c = Compiler()
    rest_of_line = c.process_attributes("href=# <asdf>")
    self.assertEqual(c.tag_attributes, [' href="#"'])
    self.assertEqual(rest_of_line, "<asdf>")
    
    c = Compiler()
    rest_of_line = c.process_attributes("val1=val1 data-val2=<%= val2 %> <asdf>")
    self.assertEqual(c.tag_attributes, [' val1="val1"', ' data-val2="<%= val2 %>"'])
    self.assertEqual(rest_of_line, "<asdf>")
    
    c = Compiler()
    rest_of_line = c.process_attributes("val1=val1 data-val2=<%= val2 %> <asdf <%= val3 %>>")
    self.assertEqual(c.tag_attributes, [' val1="val1"', ' data-val2="<%= val2 %>"'])
    self.assertEqual(rest_of_line, "<asdf <%= val3 %>>")
  
  def test_process_next_line(self):
    c = Compiler()
    c.text = "div\ndiv"
    c.process_next_line()
    self.assertEqual(c.inner_text, None)
    
    c = Compiler()
    c.text = "div <asdf>\ndiv"
    c.process_next_line()
    self.assertEqual(c.inner_text, "asdf")
    
    c = Compiler()
    c.text = "div <<%= val %> asdf>\ndiv"
    c.process_next_line()
    self.assertEqual(c.inner_text, "<%= val %> asdf")
    
    c = Compiler()
    c.text = "div href=# <asdf \n asdf ;lkj <%= val %>>\ndiv"
    c.process_next_line()
    self.assertEqual(c.inner_text, "asdf asdf ;lkj <%= val %>")
    
    c = Compiler()
    c.indent_token = "  "
    c.text = "div \-\ a href=# <asdf>"
    c.process_next_line()
    self.assertEqual(c.output, '<div>\n  <a href="#">asdf</a>\n')
  
    c = Compiler()
    c.indent_token = "  "
    c.text = "div \-\ a href=# target=_blank \-\ span <asdf>"
    c.process_next_line()
    self.assertEqual(c.output, '<div>\n  <a href="#" target="_blank">\n    <span>asdf</span>\n')
  
  def test_add_html_to_output(self):
    c = Compiler()
    c.line_starts_with_tick = True
    c.add_html_to_output()
    self.assertEqual(c.output, '')
    
    c = Compiler()
    c.line_starts_with_tick = False
    c.tag = 'input'
    c.tag_id = 'name-input'
    c.tag_classes = ['class1', 'class2']
    c.tag_attributes = [
      ' type="text"',
      ' value="Value"'
    ]
    c.self_closing = True
    c.add_html_to_output()
    self.assertEqual(c.output, '<input id="name-input" class="class1 class2" type="text" value="Value" />\n')
    
    c = Compiler()
    c.line_starts_with_tick = False
    c.compress = True
    c.tag = 'span'
    c.tag_id = None
    c.tag_classes = []
    c.tag_attributes = []
    c.self_closing = False
    c.inner_text = "<%= val1 %>"
    c.add_html_to_output()
    self.assertEqual(c.output, '<span><%= val1 %></span>')
  ###






