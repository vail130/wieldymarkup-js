
# WieldyMarkup - Nicer than HTML

## tl;dr

WieldyMarkup is an HTML abstraction markup language, similar in many ways to [Haml](http://haml.info) and [Jade](http://jade-lang.com/). However, WieldyMarkup does not do any interpolation (currently), and is meant to be part of the build & deploy process, not the page serving process. It's probably best for writing static HTML pages and templates that use Underscore or Mustache templating languages, as well.

## Installation

```shell
gem install wieldymarkup
```

## Terminal Usage

Creates `.html` files with the same file name in the same directory as compiled `.wml` files. Add `-c` or `--compress` argument to remove whitespace between HTML tags.

### Specific Files

This will fail if any files do not have the `.wml` extension. Use `-f` or `--force` anywhere to fail silently.

```shell
wieldymarkup /path/to/text_file_1.wml /path/to/text_file_2.wml
```

### In a Directory

The directory should directly follow the `-d` argument. This will only compile direct children with `.wml` extension.

```shell
wieldymarkup -d /path/to/parent/directory
```

Add `-r` to compile all `.wml` files, recursively.

## Ruby Usage

```ruby
require 'wieldymarkup'

file = File.open(filepath, 'rb')
data = file.read

# Just a one-off
html = Compiler.new(:text => data).output
compressed_html = Compiler.new(:text => data, :compress => true).output

# Or a little more flexible
c = Compiler.new
html = c.compile(:text => data)
compressed_html = c.compile(:text => data, :compress => true)
html_again = c.compile(:text => data, :compress => false)
```

## Testing

```shell
cd /path/to/wieldymarkup
rake test
```

## Indicative Example

### WieldyMarkup:

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

### Corresponding HTML Output:

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
