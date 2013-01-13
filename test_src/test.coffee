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
  
  describe '#getTagNestLevel()', ->
    it 'should return the level of nesting in a string given open and close substrings', ->
      text = "  <div>"
      expect(Compiler.getTagNestLevel text).to.equal 0
      
      text = "  <div <la;sdfajsd;f> dfajsl;fadfl   >"
      expect(Compiler.getTagNestLevel text).to.equal 0
      
      text = "  <div <la;sdfajsd;f dfajsl;fadfl   >"
      expect(Compiler.getTagNestLevel text).to.equal 1
      
      text = "  <div la;sdfajsd;f> dfajsl;fadfl   >"
      expect(Compiler.getTagNestLevel text).to.equal -1
      
      text = "  {{div {{la;sdfajsd;f}} dfajsl;fadfl   }}"
      expect(Compiler.getTagNestLevel text, '{{', '}}').to.equal 0
  
  describe '#getLeadingWhitespaceFromText()', ->
    it 'should return ', ->
      line = "    `<div class='class' id='id'>Content goes here</div>"
      expect(Compiler.getLeadingWhitespaceFromText line).to.equal "    "
      
      line = "\t\tdiv.class#id data-val=val data-val2=<%= val2 %> <Content <i>haya!</i> goes here>"
      expect(Compiler.getLeadingWhitespaceFromText line).to.equal "\t\t"
      
      line = "\n  div.class#id data-val=val data-val2=<%= val2 %> <Content <i>haya!</i> goes here>"
      expect(Compiler.getLeadingWhitespaceFromText line).to.equal ""
  

describe 'Compiler.prototype', ->
  
  describe '#constructor', ->
    it 'should set correct initial instance variables', ->
      c = new Compiler()
      c.compile()
      
      expect(c.output).to.equal ''
      expect(c.text).to.equal ''
      expect(c.compress).to.equal false
      expect(c.indentToken).to.equal ''
      expect(c.currentLevel).to.equal 0
      expect(c.previousLevel).to.equal null
      expect(c.lineNumber).to.equal 0
      
      expect(c.openTags).to.be.a 'Array'
      expect(c.openTags).to.have.length 0
  
  
  describe '#processCurrentLevel()', ->
    it 'should return the level of nesting for a line of markup', ->
      c = new Compiler()
      c.compile()
      c.text = "    div"
      c.processCurrentLevel()
      expect(c.previousLevel).to.equal 0
      expect(c.currentLevel).to.equal 1
      expect(c.indentToken).to.equal "    "
      
      c = new Compiler()
      c.compile()
      c.text = "    div"
      c.indentToken = "  "
      c.processCurrentLevel()
      expect(c.previousLevel).to.equal 0
      expect(c.currentLevel).to.equal 2
      expect(c.indentToken).to.equal "  "
      
      c = new Compiler()
      c.compile()
      c.text = "\t\tdiv"
      c.indentToken = "\t"
      c.processCurrentLevel()
      expect(c.previousLevel).to.equal 0
      expect(c.currentLevel).to.equal 2
      expect(c.indentToken).to.equal "\t"
      
      
      
  
  ###
  
  def test_close_tag(self):
    c = Compiler()
    c.indentToken = "  "
    c.open_tags = [(0, "div")]
    c.close_tag()
    expect(c.output, "</div>\n")
    expect(c.open_tags, [])
    
    c = Compiler('', compress=true)
    c.indentToken = "  "
    c.open_tags = [(0, "div")]
    c.close_tag()
    expect(c.output, "</div>")
    expect(c.open_tags, [])
  
  def test_close_lower_level_tags(self):
    c = Compiler()
    c.currentLevel = 0
    c.previousLevel = 2
    c.indentToken = "  "
    c.open_tags = [
      (0, "div"),
      (1, "div"),
      (2, "span"),
    ]
    c.close_lower_level_tags()
    expect(c.output, "    </span>\n  </div>\n</div>\n")
    
    c = Compiler('', compress=true)
    c.currentLevel = 0
    c.previousLevel = 2
    c.indentToken = "  "
    c.open_tags = [
      (0, "div"),
      (1, "div"),
      (2, "span"),
    ]
    c.close_lower_level_tags()
    expect(c.output, "</span></div></div>")
  
  def test_process_embedded_line(self):
    c = Compiler()
    c.currentLevel = 2
    c.indentToken = "  "
    c.process_embedded_line("`<div>")
    expect(c.output, "    <div>\n")
    
    c = Compiler()
    c.currentLevel = 3
    c.indentToken = "\t"
    c.process_embedded_line("`<div>")
    expect(c.output, "\t\t\t<div>\n")
    
    c = Compiler('', compress=true)
    c.currentLevel = 3
    c.indentToken = "\t"
    c.process_embedded_line("`<div>")
    expect(c.output, "<div>")
  
  def test_process_selector(self):
    c = Compiler()
    c.process_selector("div")
    expect(c.tag, "div")
    expect(c.tag_id, null)
    expect(c.tag_classes, [])
    
    c = Compiler()
    c.process_selector("span.class1#id.class2")
    expect(c.tag, "span")
    expect(c.tag_id, "id")
    expect(c.tag_classes, ["class1", "class2"])
    
    c = Compiler()
    c.process_selector("#id.class")
    expect(c.tag, "div")
    expect(c.tag_id, "id")
    expect(c.tag_classes, ["class"])
  
  def test_process_attributes(self):
    c = Compiler()
    rest_of_line = c.process_attributes("")
    expect(c.tag_attributes, [])
    expect(rest_of_line, "")
    
    c = Compiler()
    rest_of_line = c.process_attributes("href=# target=_blank")
    expect(c.tag_attributes, [' href="#"', ' target="_blank"'])
    expect(rest_of_line, "")
    
    c = Compiler()
    rest_of_line = c.process_attributes("href=# <asdf>")
    expect(c.tag_attributes, [' href="#"'])
    expect(rest_of_line, "<asdf>")
    
    c = Compiler()
    rest_of_line = c.process_attributes("val1=val1 data-val2=<%= val2 %> <asdf>")
    expect(c.tag_attributes, [' val1="val1"', ' data-val2="<%= val2 %>"'])
    expect(rest_of_line, "<asdf>")
    
    c = Compiler()
    rest_of_line = c.process_attributes("val1=val1 data-val2=<%= val2 %> <asdf <%= val3 %>>")
    expect(c.tag_attributes, [' val1="val1"', ' data-val2="<%= val2 %>"'])
    expect(rest_of_line, "<asdf <%= val3 %>>")
  
  def test_process_next_line(self):
    c = Compiler()
    c.text = "div\ndiv"
    c.process_next_line()
    expect(c.inner_text, null)
    
    c = Compiler()
    c.text = "div <asdf>\ndiv"
    c.process_next_line()
    expect(c.inner_text, "asdf")
    
    c = Compiler()
    c.text = "div <<%= val %> asdf>\ndiv"
    c.process_next_line()
    expect(c.inner_text, "<%= val %> asdf")
    
    c = Compiler()
    c.text = "div href=# <asdf \n asdf ;lkj <%= val %>>\ndiv"
    c.process_next_line()
    expect(c.inner_text, "asdf asdf ;lkj <%= val %>")
    
    c = Compiler()
    c.indentToken = "  "
    c.text = "div \-\ a href=# <asdf>"
    c.process_next_line()
    expect(c.output, '<div>\n  <a href="#">asdf</a>\n')
  
    c = Compiler()
    c.indentToken = "  "
    c.text = "div \-\ a href=# target=_blank \-\ span <asdf>"
    c.process_next_line()
    expect(c.output, '<div>\n  <a href="#" target="_blank">\n    <span>asdf</span>\n')
  
  def test_add_html_to_output(self):
    c = Compiler()
    c.line_starts_with_tick = true
    c.add_html_to_output()
    expect(c.output, '')
    
    c = Compiler()
    c.line_starts_with_tick = false
    c.tag = 'input'
    c.tag_id = 'name-input'
    c.tag_classes = ['class1', 'class2']
    c.tag_attributes = [
      ' type="text"',
      ' value="Value"'
    ]
    c.self_closing = true
    c.add_html_to_output()
    expect(c.output, '<input id="name-input" class="class1 class2" type="text" value="Value" />\n')
    
    c = Compiler()
    c.line_starts_with_tick = false
    c.compress = true
    c.tag = 'span'
    c.tag_id = null
    c.tag_classes = []
    c.tag_attributes = []
    c.self_closing = false
    c.inner_text = "<%= val1 %>"
    c.add_html_to_output()
    expect(c.output, '<span><%= val1 %></span>')
  ###






