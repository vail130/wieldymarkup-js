// Generated by CoffeeScript 1.3.3
(function() {
  var WieldyJS, exports, _,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  _ = require('underscore');

  _.str = require('underscore.string');

  WieldyJS = (function() {

    WieldyJS.whitespace = " \t";

    /*
      Removes all substrings surrounded by a grouping substring, including
        grouping substring on both sides.
      
      @param <String> text - The string from which to remove grouped substrings
      @param <String> z - The grouping substring
      @return <String> - The string with substrings removed
    */


    WieldyJS.removeGroupedText = function(text, groupingToken) {
      var groupingTokenIndex, output, status;
      output = "";
      status = true;
      while (text !== '') {
        groupingTokenIndex = text.indexOf(groupingToken);
        if (groupingTokenIndex === -1) {
          if (status) {
            output += text;
          }
          text = '';
        } else {
          if (status) {
            output += text.substring(0, groupingTokenIndex);
          }
          if (text.length > groupingTokenIndex + 2) {
            text = text.substring(groupingTokenIndex + 1, text.length);
          } else {
            text = '';
          }
        }
        status = !status;
      }
      return output;
    };

    /*
      Gets the selector from the line of markup
      
      @param <String> line - The string from which to get the selector
      @return <String> selector - The substring from the beginning of the line until the
        first whitespace character
    */


    WieldyJS.getSelectorFromLine = function(line) {
      var ch, firstWhitespaceIndex, i, selector, _i, _len, _ref;
      selector = line;
      firstWhitespaceIndex = -1;
      _ref = line.split("");
      for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
        ch = _ref[i];
        if (WieldyJS.whitespace.indexOf(ch) > -1) {
          firstWhitespaceIndex = i;
          break;
        }
      }
      if (firstWhitespaceIndex > -1) {
        selector = selector.substring(0, firstWhitespaceIndex);
      }
      return selector;
    };

    /*
      Determines the level of nesting in a string
      
      @param <String> text - The string in which to determine the nest level
      @param <String> openString - The substring that denotes an increase in
        nesting level.
      @param <String> closeString - The substring that denotes a decrase in
        nesting level.
      @return <String> nestLevel - The substring from the beginning of the line
        until the first whitespace character
    */


    WieldyJS.getTagNestLevel = function(text, openString, closeString) {
      var closeStringFirst, closeStringIndex, nestLevel, openStringFirst, openStringIndex;
      if (openString == null) {
        openString = '<';
      }
      if (closeString == null) {
        closeString = '>';
      }
      nestLevel = 0;
      while (true) {
        openStringIndex = text.indexOf(openString);
        closeStringIndex = text.indexOf(closeString);
        openStringFirst = false;
        closeStringFirst = false;
        if (openStringIndex === -1 && closeStringIndex === -1) {
          break;
        } else if (openStringIndex !== -1) {
          openStringFirst = true;
        } else if (closeStringIndex !== -1) {
          closeStringFirst = true;
        } else {
          if (openStringIndex < closeStringIndex) {
            openStringFirst = true;
          } else {
            closeStringFirst = true;
          }
        }
        if (openStringFirst) {
          nestLevel++;
          if (text.length === openStringIndex + openString.length) {
            break;
          } else {
            text = text.substring(openStringIndex + openString.length, text.length);
          }
        } else if (closeStringFirst) {
          nestLevel--;
          if (text.length === closeStringIndex + closeString.length) {
            break;
          } else {
            text = text.substring(closeStringIndex + closeString.length, text.length);
          }
        }
      }
      return nestLevel;
    };

    /*
      Gets the string of leading spaces and tabs in some text.
      
      @param <String> text - The string from which to get the leading whitespace
      @return <String> leadingWhitespace - The leading whitespace in the string
    */


    WieldyJS.getLeadingWhitespaceFromText = function(text) {
      var ch, i, leadingWhitespace, _i, _len, _ref;
      leadingWhitespace = "";
      _ref = text.split("");
      for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
        ch = _ref[i];
        if (WieldyJS.whitespace.indexOf(ch) === -1) {
          leadingWhitespace = text.substring(0, i);
          break;
        }
      }
      return leadingWhitespace;
    };

    /*
      Instantiate a new Compiler instance. Automatically compiles text if passed
        in via parameters.
      
      @param <String> text - The input text to compile
      @param <Boolean> compress - Whether to leave whitespace between HTML tags or not
    */


    function WieldyJS(text, compress) {
      if (text == null) {
        text = "";
      }
      if (compress == null) {
        compress = false;
      }
      this.addHtmlToOutput = __bind(this.addHtmlToOutput, this);

      this.processAttributes = __bind(this.processAttributes, this);

      this.processSelector = __bind(this.processSelector, this);

      this.processEmbeddedLine = __bind(this.processEmbeddedLine, this);

      this.processNextLine = __bind(this.processNextLine, this);

      this.closeTag = __bind(this.closeTag, this);

      this.closeLowerLevelTags = __bind(this.closeLowerLevelTags, this);

      this.processCurrentLevel = __bind(this.processCurrentLevel, this);

      this.text = text;
      this.compress = compress;
      this.compile();
    }

    /*
      Compiles input markup into HTML.
      
      @param <String> text - The input text to compile
      @param <Boolean> compress - Whether to leave whitespace between HTML tags or not
      @return <String> The compiled HTML
    */


    WieldyJS.prototype.compile = function(text, compress) {
      if (text == null) {
        text = null;
      }
      if (compress == null) {
        compress = null;
      }
      if (text !== null) {
        this.text = text;
      }
      if (compress !== null) {
        this.compress = !!compress;
      }
      this.output = "";
      this.openTags = [];
      this.indentToken = "";
      this.currentLevel = 0;
      this.previousLevel = null;
      this.lineNumber = 0;
      this.embeddingToken = '`';
      while (this.text !== "") {
        this.processCurrentLevel().closeLowerLevelTags().processNextLine();
      }
      while (this.openTags.length > 0) {
        this.closeTag();
      }
      return this.output;
    };

    /*
      Determines current nesting level for HTML output.
      
      @return <Object> this - The reference to this instance object.
    */


    WieldyJS.prototype.processCurrentLevel = function() {
      var i, leadingWhitespace;
      this.previousLevel = this.currentLevel;
      leadingWhitespace = this.constructor.getLeadingWhitespaceFromText(this.text);
      if (leadingWhitespace === "") {
        this.currentLevel = 0;
      } else if (this.indentToken === "") {
        this.indentToken = leadingWhitespace;
        this.currentLevel = 1;
      } else {
        i = 0;
        while (_.str.startsWith(leadingWhitespace, this.indentToken)) {
          leadingWhitespace = leadingWhitespace.substring(this.indentToken.length, leadingWhitespace.length);
          i += 1;
        }
        this.currentLevel = i;
      }
      return this;
    };

    /*
      Iterates through nesting levels that have been closed.
      
      @return <Object> this - The reference to this instance object.
    */


    WieldyJS.prototype.closeLowerLevelTags = function() {
      if (this.currentLevel <= this.previousLevel) {
        while (this.openTags.length > 0 && this.openTags[this.openTags.length - 1][0] >= this.currentLevel) {
          this.closeTag();
        }
      }
      return this;
    };

    /*
      Adds closing HTML tags to output and removes entry from @openTags.
      
      @return <Object> this - The reference to this instance object.
    */


    WieldyJS.prototype.closeTag = function() {
      var closingTagArray;
      closingTagArray = this.openTags.pop();
      if (!this.compress && closingTagArray[0] > 0) {
        this.output += _.str.repeat(this.indentToken, closingTagArray[0]);
      }
      this.output += "</" + closingTagArray[1] + ">";
      if (!this.compress) {
        this.output += "\n";
      }
      return this;
    };

    /*
      Gets the next line of text, splits it into relevant pieces, and sends them
        to respective methods for parsing.
      
      @return <Object> this - The reference to this instance object.
    */


    WieldyJS.prototype.processNextLine = function() {
      var line, lineBreakIndex, lineSplitList, restOfLine, selector, temp_line;
      this.lineStartsWithTick = false;
      this.selfClosing = false;
      this.innerText = null;
      line = "";
      if (__indexOf.call(this.text, "\n") >= 0) {
        lineBreakIndex = this.text.indexOf("\n");
        line = _.str.trim(this.text.substring(0, lineBreakIndex));
        this.text = this.text.substring(lineBreakIndex + 1, this.text.length);
      } else {
        line = _.str.trim(this.text);
        this.text = "";
      }
      this.lineNumber += 1;
      if (line.length === 0) {
        return this;
      }
      if (line[0] === this.embeddingToken) {
        this.processEmbeddedLine(line);
      } else {
        lineSplitList = line.split('\\-\\');
        while (lineSplitList.length > 1) {
          temp_line = _.str.trim(lineSplitList.shift());
          selector = this.constructor.getSelectorFromLine(temp_line);
          this.processSelector(selector);
          restOfLine = _.str.trim(temp_line.substring(selector.length, temp_line.length));
          restOfLine = this.processAttributes(restOfLine);
          this.addHtmlToOutput();
          this.tag = null;
          this.tagId = null;
          this.tagClasses = [];
          this.tagAttributes = [];
          this.previousLevel = this.currentLevel;
          this.currentLevel++;
        }
        line = _.str.trim(lineSplitList[lineSplitList.length - 1]);
        selector = this.constructor.getSelectorFromLine(line);
        this.processSelector(selector);
        restOfLine = _.str.trim(line.substring(selector.length, line.length));
        restOfLine = this.processAttributes(restOfLine);
        if (_.str.startsWith(restOfLine, '<')) {
          this.innerText = restOfLine;
          if (this.constructor.getTagNestLevel(this.innerText) < 0) {
            throw "Too many '>' found on line " + this.lineNumber;
          }
          while (this.constructor.getTagNestLevel(this.innerText) > 0) {
            if (this.text === "") {
              throw "Unmatched '<' found on line " + this.lineNumber;
            } else if (__indexOf.call(this.text, "\n") >= 0) {
              lineBreakIndex = this.text.indexOf("\n");
              this.innerText += ' ' + _.str.trim(this.text.substring(0, lineBreakIndex));
              if (this.text.length === lineBreakIndex + 1) {
                this.text = "";
              } else {
                this.text = this.text.substring(lineBreakIndex + 1, this.text.length);
              }
            } else {
              this.innerText += this.text;
              this.text = "";
            }
          }
          this.innerText = _.str.trim(this.innerText).substring(1, this.innerText.length - 1);
        } else if (_.str.startsWith(restOfLine, '/')) {
          if (restOfLine.length > 0 && restOfLine[restOfLine.length - 1] === '/') {
            this.selfClosing = true;
          }
        }
        this.addHtmlToOutput();
      }
      return this;
    };

    /*
      Adds an embedded line to output, removing @embedding_token
        and not compiling.
      
      @param <String> line - The line of text with @embedding_token
      @return <Object> this - The reference to this instance object.
    */


    WieldyJS.prototype.processEmbeddedLine = function(line) {
      this.lineStartsWithTick = true;
      if (!this.compress) {
        this.output += _.str.repeat(this.indentToken, this.currentLevel);
      }
      this.output += _.str.trim(line).substr(1);
      if (!this.compress) {
        this.output += "\n";
      }
      return this;
    };

    /*
      Parses a selector into tag, ID, and classes.
      
      @param <String> selector - The unparsed selector string
      @return <Object> this - The reference to this instance object.
    */


    WieldyJS.prototype.processSelector = function(selector) {
      var ch, delimiterIndex, i, nextDelimiterIndex, _i, _j, _len, _len1, _ref, _ref1;
      if (selector.length > 0 && ((_ref = selector[0]) === '#' || _ref === '.')) {
        this.tag = 'div';
      } else {
        delimiterIndex = null;
        _ref1 = selector.split("");
        for (i = _i = 0, _len = _ref1.length; _i < _len; i = ++_i) {
          ch = _ref1[i];
          if (ch === '#' || ch === '.') {
            delimiterIndex = i;
            break;
          }
        }
        if (delimiterIndex === null) {
          this.tag = selector;
          selector = "";
        } else {
          this.tag = selector.substring(0, delimiterIndex);
          selector = selector.substring(this.tag.length, selector.length);
        }
      }
      this.tagId = null;
      this.tagClasses = [];
      while (true) {
        nextDelimiterIndex = null;
        if (selector === "") {
          break;
        } else {
          for (i = _j = 0, _len1 = selector.length; _j < _len1; i = ++_j) {
            ch = selector[i];
            if (i > 0 && (ch === '#' || ch === '.')) {
              nextDelimiterIndex = i;
              break;
            }
          }
          if (nextDelimiterIndex === null) {
            if (selector[0] === '#') {
              this.tagId = selector.substring(1, selector.length);
            } else if (selector[0] === ".") {
              this.tagClasses.push(selector.substring(1, selector.length));
            }
            selector = "";
          } else {
            if (selector[0] === '#') {
              this.tagId = selector.substring(1, nextDelimiterIndex);
            } else if (selector[0] === ".") {
              this.tagClasses.push(selector.substring(1, nextDelimiterIndex));
            }
            selector = selector.substring(nextDelimiterIndex, selector.length);
          }
        }
      }
      return this;
    };

    /*
      Parses attribute string off of the beginning of a line of text after
        the selector was removed, and returns everything after the attribute
        string.
      
      @param <String> rest_of_line - The line of text after leading whitespace and selector have been removed
      @return <String> this - The input text after all attributes have been removed
    */


    WieldyJS.prototype.processAttributes = function(restOfLine) {
      var ch, closeIndex, currentAttribute, embeddedAttribute, equalsIndex, firstEqualsIndex, i, reversedLettersBetweenEquals, secondEqualsIndex, whitespaceIndex, _i, _len;
      this.tagAttributes = [];
      while (restOfLine !== "") {
        if (__indexOf.call(restOfLine, '=') < 0) {
          break;
        } else if (__indexOf.call(restOfLine, '=') >= 0 && __indexOf.call(restOfLine, '<') >= 0 && restOfLine.indexOf('<') < restOfLine.indexOf('=')) {
          break;
        }
        firstEqualsIndex = restOfLine.indexOf('=');
        embeddedAttribute = false;
        if (restOfLine.substr(firstEqualsIndex + 1, 2) === '{{') {
          embeddedAttribute = true;
          closeIndex = restOfLine.indexOf('}}');
          if (closeIndex === -1) {
            throw "Unmatched '{{' found in line " + this.lineNumber;
          }
        } else if (restOfLine.substr(firstEqualsIndex + 1, 2) === '<%') {
          embeddedAttribute = true;
          closeIndex = restOfLine.indexOf('%>');
          if (closeIndex === -1) {
            throw "Unmatched '<%' found in line " + this.lineNumber;
          }
        }
        if (embeddedAttribute) {
          currentAttribute = restOfLine.substring(0, closeIndex + 2);
          if (restOfLine.length === closeIndex + 2) {
            restOfLine = "";
          } else {
            restOfLine = restOfLine.substr(closeIndex + 2);
          }
        } else if (restOfLine.length === firstEqualsIndex + 1) {
          currentAttribute = _.str.trim(restOfLine);
          restOfLine = "";
        } else if (__indexOf.call(restOfLine.substr(firstEqualsIndex + 1), '=') < 0) {
          if (__indexOf.call(restOfLine, '<') >= 0) {
            currentAttribute = _.str.trim(restOfLine.substring(0, restOfLine.indexOf('<')));
            restOfLine = restOfLine.substr(restOfLine.indexOf('<'));
          } else {
            currentAttribute = restOfLine;
            restOfLine = "";
          }
        } else {
          secondEqualsIndex = restOfLine.substr(firstEqualsIndex + 1).indexOf('=');
          reversedLettersBetweenEquals = _.str.reverse(restOfLine.substring(firstEqualsIndex + 1, firstEqualsIndex + 1 + secondEqualsIndex));
          whitespaceIndex = null;
          for (i = _i = 0, _len = reversedLettersBetweenEquals.length; _i < _len; i = ++_i) {
            ch = reversedLettersBetweenEquals[i];
            if (" \t".indexOf(ch) > -1) {
              whitespaceIndex = firstEqualsIndex + 1 + secondEqualsIndex - i;
              break;
            }
          }
          if (whitespaceIndex === null) {
            break;
          }
          currentAttribute = _.str.trim(restOfLine.substring(0, whitespaceIndex));
          restOfLine = restOfLine.substr(whitespaceIndex);
        }
        if (currentAttribute !== null) {
          equalsIndex = currentAttribute.indexOf('=');
          this.tagAttributes.push((" " + (currentAttribute.substring(0, equalsIndex)) + "=") + ("" + ('"' + currentAttribute.substr(equalsIndex + 1) + '"')));
        }
      }
      return _.str.trim(restOfLine);
    };

    /*
      Adds HTML to output for a given line.
      
      @return <Object> this - The reference to this instance object.
    */


    WieldyJS.prototype.addHtmlToOutput = function() {
      var tagHtml;
      if (!this.lineStartsWithTick) {
        tagHtml = "<" + this.tag;
        if (this.tagId !== null) {
          tagHtml += " id=\"" + this.tagId + "\"";
        }
        if (this.tagClasses.length > 0) {
          tagHtml += " class=\"" + this.tagClasses.join(' ') + "\"";
        }
        if (this.tagAttributes.length > 0) {
          tagHtml += this.tagAttributes.join('');
        }
        if (this.selfClosing) {
          tagHtml += " />";
          if (!this.compress) {
            this.output += _.str.repeat(this.indentToken, this.currentLevel);
          }
          this.output += tagHtml;
          if (!this.compress) {
            this.output += "\n";
          }
        } else {
          tagHtml += ">";
          if (this.innerText !== null) {
            tagHtml += this.innerText;
          }
          if (!this.compress) {
            this.output += _.str.repeat(this.indentToken, this.currentLevel);
          }
          this.output += tagHtml;
          if (this.innerText === null) {
            if (!this.compress) {
              this.output += "\n";
            }
            this.openTags.push([this.currentLevel, this.tag]);
          } else {
            this.output += "</" + this.tag + ">";
            if (!this.compress) {
              this.output += "\n";
            }
          }
        }
      }
      return this;
    };

    return WieldyJS;

  }).call(this);

  exports = module.exports = {
    Compiler: WieldyJS
  };

}).call(this);
