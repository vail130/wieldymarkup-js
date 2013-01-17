
# WieldyMarkup - Template-agnostic markup that's clean and compiles to HTML

## Installation

```shell
npm install wieldyjs -g
wieldyjs

WieldyJS: WieldyMarkup Compiler for Node
  
  Usage:
    wieldyjs [options]* [(file | dir)* | ((-m | --mirror) in-dir out-dir)]
  
  Usage Syntax:
    `[` and `]` denote optional groups
    `(` and `)` denote semantic groups
    `*` denotes 0 or more of the preceeding entity
    `|` denotes OR relationship between preceeding and proceeding entities
  
  Global Options:
    -h OR --help        Show this help message.
    -v OR --verbose     Display messages describing compiler behavior.
    -c OR --compress    Output HTML files without whitespace between tags.
    -r OR --recursive   Search recursively inside directories for .wml files.
  
```

## Terminal Usage

There are two main ways to use WieldyJS:

1. List `.wml` files and directories containing `.wml` files, and WieldyJS will compile `.html` versions in the same location.

2. Use the `-m` or `--mirror` option and list an input directory and output directory, in that order. WieldyJS will find all `.wml` files in the input directory and compile them to `.html` files in the output directory.

## Node Usage

This will fail if any files do not have the `.wml` extension. Use `-f` or `--force` anywhere to fail silently.

```javascript
var fs = require('fs');
var Compiler = require('wieldyjs');

// Just a one-off
fs.readFile('/path/to/file', 'utf8', function(err, data) {
  if (err) { return console.log(err); }
  var html = new Compiler(data).output;
  var compressed_html = new Compiler(data, true).output;
});

// Or a little more flexible
var c = new Compiler();
fs.readFile('/path/to/file', 'utf8', function(err, data) {
  if (err) { return console.log(err); }
  var html = c.compile(data).output;
  var compressed_html = c.compile(data, true).output;
  var html_again = c.compile(data, false).output;
});
```

## Testing

```shell
cd /path/to/wieldymarkup
mocha
```

## WieldyMarkup Syntax:

### WML:

```
`<!DOCTYPE html>
html lang=en
  head
    title <My Website>
  body
    #application
      .navbar
        .navbar-inner
          a.brand href=# <Title>
          ul.nav
            li.active \-\ a href=#
                i.icon-pencil
                span <Home>
            li
              a href=# <Link>
      form enctype=multipart/form-data
        `<% var d = new Date(); %>
        input.underscore-template type=text readonly= value=<%= d.getDate() %> /
        input.mustache-template type=text readonly= value={{ val2 }} /
        p <<%= val %> {{ val }} Lorem ipsum dolor sit amet, consectetur adipisicing elit,
          sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.>
```

### HTML:

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <title>My Website</title>
  </head>
  <body>
    <div id="application">
      <div class="navbar">
        <div class="navbar-inner">
          <a class="brand" href="#">Title</a>
          <ul class="nav">
            <li class="active">
              <a href="#">
                <i class="icon-pencil">
                </i>
                <span>Home</span>
              </a>
            </li>
            <li>
              <a href="#">Link</a>
            </li>
          </ul>
        </div>
      </div>
      <form enctype="multipart/form-data">
        <% var d = new Date(); %>
        <input class="underscore-template" type="text" readonly="" value="<%= d.getDate() %>" />
        <input class="mustache-template" type="text" readonly="" value="{{ val2 }}" />
        <p><%= val %> {{ val }} Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.</p>
      </form>
    </div>
  </body>
</html>
```

## Guide

There are five steps to parsing each line of WieldyMarkup:

1. Leading whitespace
2. Multi-Tag Delimiter
3. Selector
4. Attributes
5. InnerText or self-closing designation

### Leading Whitespace

Each line's Leading whitespace is used to detect it's nesting level. Use either tabs or spaces for indentation, but not both. The number of tabs or spaces that comprises an indentation is determined on the first line with any leading tabs or spaces, and then that is the standard used for the rest of the file.

### Selector

Tag designations are modelled after CSS selectors. WieldyMarkup currently only supports tag, class, and ID as part of the selector.

* If you want to specify a tag, then it must come before classes or ID.
* If there is no ID or class, then you must specify a tag.
* If there is at least one class or an ID, then no tag will default to a `DIV`.
* If multiple IDs are present, only the last one will be used.

### Multi-Tag Delimiter

For designating multiple, nested HTML tags on a single line in WieldyMarkup, use the `\-\` delimiter between them. This is especially useful in a list of links. For example:

```
ul
  li.active \-\ a href=# <Home>
  li \-\ a href=# <Link>
  li \-\ a href=#
      i.icon-pencil
      span <Link>
  li \-\ a href=# \-\ span <Link>
```

becomes

```html
<ul>
  <li class="active">
    <a href="#">Home</a>
  </li>
  <li>
    <a href="#">
      <i class="icon-pencil">
      </i>
      <span>Link</span>
    </a>
  </li>
  <li>
    <a href="#">
      <span>Link</span>
    </a>
  </li>
</ul>
```

Be careful nesting inside of an element after it is declared in a multi-tag line. You still have to indent to the proper level for following lines to be nested inside. Note the indentation of `i.icon-pencil` in the example above.

### Attributes

The list of attributes begins after the first whitespace character after the beginning of the selector. Key-value pairs are identified by three elements:

1. A key containing no whitespace characters or an equals sign (`=`)
2. An equals sign (`=`)
3. Either (1) a string starting with `<%` or `{{` and ending with `%>` or `}}`, between which all characters are ignored, or (2) a string ending either at the innerText designation, the last whitespace character before the next `=`, or the end of the line

### InnerText and Self-Closing Designation

If the line ends with `/`, then the tag will be treated as self-closing.

If the line ends with innerText wrapped in `<` and `>`, or if the innerText spills over into proceeding lines and eventually ends with `>`, then everything between `<` and `>` will be designated as innerText for the HTML tag. The compiler will leave instances of `<% [anything here] %>`, as long as each instance is opened and closed on the same line; this restriction does not apply to `{{ [anything here] }}`. Leading whitespace for continuing lines of innerText is ignored and transformed into a single space.
