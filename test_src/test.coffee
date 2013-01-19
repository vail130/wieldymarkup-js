expect = require('chai').expect
Compiler = require('../lib/wieldyjs').Compiler
Commander = require('../bin/wieldyjs').Commander

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
      c = new Compiler
      
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
      c = new Compiler
      c.text = "    div"
      c.processCurrentLevel()
      expect(c.previousLevel).to.equal 0
      expect(c.currentLevel).to.equal 1
      expect(c.indentToken).to.equal "    "
      
      c = new Compiler
      c.text = "    div"
      c.indentToken = "  "
      c.processCurrentLevel()
      expect(c.previousLevel).to.equal 0
      expect(c.currentLevel).to.equal 2
      expect(c.indentToken).to.equal "  "
      
      c = new Compiler
      c.text = "\t\tdiv"
      c.indentToken = "\t"
      c.processCurrentLevel()
      expect(c.previousLevel).to.equal 0
      expect(c.currentLevel).to.equal 2
      expect(c.indentToken).to.equal "\t"
  
  describe '#closeTag()', ->
    it 'should close a tag listed as open in the openTags instance variable', ->
      c = new Compiler
      c.indentToken = "  "
      c.openTags = [[0, "div"]]
      c.closeTag()
      expect(c.output).to.equal "</div>\n"
      expect(c.openTags).to.have.length 0
      expect(c.openTags).to.be.a 'Array'
      
      c = new Compiler '', true
      c.indentToken = "  "
      c.openTags = [[0, "div"]]
      c.closeTag()
      expect(c.output).to.equal "</div>"
      expect(c.openTags).to.have.length 0
      expect(c.openTags).to.be.a 'Array'
  
  describe '#closeLowerLevelTags()', ->
    it 'should add closing tags to output for all open tags', ->
      c = new Compiler
      c.currentLevel = 0
      c.previousLevel = 2
      c.indentToken = "  "
      c.openTags = [
        [0, "div"]
        [1, "div"]
        [2, "span"]
      ]
      c.closeLowerLevelTags()
      expect(c.output).to.equal "    </span>\n  </div>\n</div>\n"
      
      c = new Compiler '', true
      c.currentLevel = 0
      c.previousLevel = 2
      c.indentToken = "  "
      c.openTags = [
        [0, "div"]
        [1, "div"]
        [2, "span"]
      ]
      c.closeLowerLevelTags()
      expect(c.output).to.equal "</span></div></div>"
  
  describe '#processEmbeddedLine()', ->
    it 'should add unchanged line to output with ` removed', ->
      c = new Compiler
      c.currentLevel = 2
      c.indentToken = "  "
      c.processEmbeddedLine "`<div>"
      expect(c.output).to.equal "    <div>\n"
      
      c = new Compiler
      c.currentLevel = 3
      c.indentToken = "\t"
      c.processEmbeddedLine "`<div>"
      expect(c.output).to.equal "\t\t\t<div>\n"
      
      c = new Compiler '', true
      c.currentLevel = 3
      c.indentToken = "\t"
      c.processEmbeddedLine "`<div>"
      expect(c.output).to.equal "<div>"
  
  describe '#processSelector()', ->
    it 'should parse a selector string into components', ->
      c = new Compiler
      c.processSelector "div"
      expect(c.tag).to.equal "div"
      expect(c.tagId).to.equal null
      expect(c.tagClasses).to.be.a 'Array'
      expect(c.tagClasses).to.have.length 0
      
      c = new Compiler
      c.processSelector "span.class1#id.class2"
      expect(c.tag).to.equal "span"
      expect(c.tagId).to.equal "id"
      expect(c.tagClasses).to.be.a 'Array'
      expect(c.tagClasses).to.have.length 2
      expect(c.tagClasses[0]).to.equal "class1"
      expect(c.tagClasses[1]).to.equal "class2"
      
      c = new Compiler
      c.processSelector "#id.class"
      expect(c.tag).to.equal "div"
      expect(c.tagId).to.equal "id"
      expect(c.tagClasses).to.be.a 'Array'
      expect(c.tagClasses).to.have.length 1
      expect(c.tagClasses[0]).to.equal "class"
  
  describe '#processAttributes()', ->
    it 'should parse attribute string into components and return the rest of the text', ->
      c = new Compiler
      rest_of_line = c.processAttributes ""
      expect(c.tagAttributes).to.be.a 'Array'
      expect(c.tagAttributes).to.have.length 0
      expect(rest_of_line).to.equal ""
      
      c = new Compiler
      rest_of_line = c.processAttributes "href=# target=_blank"
      expect(c.tagAttributes).to.be.a 'Array'
      expect(c.tagAttributes).to.have.length 2
      expect(c.tagAttributes[0]).to.equal ' href="#"'
      expect(c.tagAttributes[1]).to.equal ' target="_blank"'
      expect(rest_of_line).to.equal ""
      
      c = new Compiler
      rest_of_line = c.processAttributes "href=# <asdf>"
      expect(c.tagAttributes).to.be.a 'Array'
      expect(c.tagAttributes).to.have.length 1
      expect(c.tagAttributes[0]).to.equal ' href="#"'
      expect(rest_of_line).to.equal "<asdf>"
      
      c = new Compiler
      rest_of_line = c.processAttributes "val1=val1 data-val2=<%= val2 %> <asdf>"
      expect(c.tagAttributes).to.be.a 'Array'
      expect(c.tagAttributes).to.have.length 2
      expect(c.tagAttributes[0]).to.equal ' val1="val1"'
      expect(c.tagAttributes[1]).to.equal ' data-val2="<%= val2 %>"'
      expect(rest_of_line).to.equal "<asdf>"
      
      c = new Compiler
      rest_of_line = c.processAttributes "val1=val1 data-val2=<%= val2 %> <asdf <%= val3 %>>"
      expect(c.tagAttributes).to.be.a 'Array'
      expect(c.tagAttributes).to.have.length 2
      expect(c.tagAttributes[0]).to.equal ' val1="val1"'
      expect(c.tagAttributes[1]).to.equal ' data-val2="<%= val2 %>"'
      expect(rest_of_line).to.equal "<asdf <%= val3 %>>"
  
  describe '#processNextLine()', ->
    it 'should put everything after the attribute string inside of "<" and ' +
      '">", across line breaks into innerText', ->
        
      c = new Compiler
      c.text = "div\ndiv"
      c.processNextLine()
      expect(c.innerText).to.equal null
      
      c = new Compiler
      c.text = "div <asdf>\ndiv"
      c.processNextLine()
      expect(c.innerText).to.equal "asdf"
      
      c = new Compiler
      c.text = "div <<%= val %> asdf>\ndiv"
      c.processNextLine()
      expect(c.innerText).to.equal "<%= val %> asdf"
      
      c = new Compiler
      c.text = "div href=# <asdf \n asdf ;lkj <%= val %>>\ndiv"
      c.processNextLine()
      expect(c.innerText).to.equal "asdf asdf ;lkj <%= val %>"
      
      c = new Compiler
      c.indentToken = "  "
      c.text = "div \\-\\ a href=# <asdf>"
      c.processNextLine()
      expect(c.output).to.equal '<div>\n  <a href="#">asdf</a>\n'
    
      c = new Compiler
      c.indentToken = "  "
      c.text = "div \\-\\ a href=# target=_blank \\-\\ span <asdf>"
      c.processNextLine()
      expect(c.output).to.equal '<div>\n  <a href="#" target="_blank">\n    <span>asdf</span>\n'
  
  describe '#add_html_to_output()', ->
    it 'should add HTML to output correctly based on parsed tag data', ->
      c = new Compiler
      c.lineStartsWithTick = true
      c.addHtmlToOutput()
      expect(c.output).to.equal ''
      
      c = new Compiler
      c.lineStartsWithTick = false
      c.tag = 'input'
      c.tagId = 'name-input'
      c.tagClasses = ['class1', 'class2']
      c.tagAttributes = [
        ' type="text"',
        ' value="Value"'
      ]
      c.selfClosing = true
      c.addHtmlToOutput()
      expect(c.output).to.equal '<input id="name-input" class="class1 class2" type="text" value="Value" />\n'
      
      c = new Compiler
      c.lineStartsWithTick = false
      c.compress = true
      c.tag = 'span'
      c.tagId = null
      c.tagClasses = []
      c.tagAttributes = []
      c.selfClosing = false
      c.innerText = "<%= val1 %>"
      c.addHtmlToOutput()
      expect(c.output).to.equal '<span><%= val1 %></span>'


describe 'Commander', ->
  
  describe '#getOutputFile(inputDir, outputDir, inputFile)', ->
    it 'should return output filename based on input dir, output dir, and input filename', ->
      inputDir = '/Users/user/Projects/project/templates'
      outputDir = '/Users/user/Projects/project/templates'
      inputFile = '/Users/user/Projects/project/templates/file1.wml'
      expect(
        Commander.getOutputFile inputDir, outputDir, inputFile
      ).to.equal '/Users/user/Projects/project/templates/file1.html'
      
      inputDir = '/Users/user/Projects/project/templates_src'
      outputDir = '/Users/user/Projects/project/templates_dest'
      inputFile = '/Users/user/Projects/project/templates_src/file1.wml'
      expect(
        Commander.getOutputFile inputDir, outputDir, inputFile
      ).to.equal '/Users/user/Projects/project/templates_dest/file1.html'
  
  describe '#getDirsForPath(filePath)', ->
    it 'should return an array of directories that a filePath requires to resolve', ->
      filePath = '/Users/user/Projects/project/templates/file1.wml'
      result = Commander.getDirsForPath filePath
      expect(result).to.be.a 'Array'
      expect(result).to.have.length 5
      
      filePath = '/.__WIELDYJSTESTDIR/user'
      result = Commander.getDirsForPath filePath
      expect(result).to.be.a 'Array'
      expect(result).to.have.length 1


describe 'Commander.prototype', ->
  
  describe '#init([args])', ->
    it 'should set instance variables to determine behavior', ->
      c = new Commander ['-h', '-v', '-c', '-m']
      expect(c).to.have.property 'init'
      expect(c.help and c.verbose and c.compress and c.mirror).to.equal true
      expect(c.args).to.have.length 0
      
      c = new Commander ['-h', '--verbose']
      expect(c.help and c.verbose).to.equal true
      expect(c.compress or c.mirror).to.equal false
      expect(c.args).to.have.length 0
      
      c = new Commander ['--help', '--verbose', '--compress', '--mirror']
      expect(c.help and c.verbose and c.compress and c.mirror).to.equal true
      expect(c.args).to.have.length 0
      
  
