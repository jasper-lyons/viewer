# Viewer
> Only load the js and css that you need for each page.

Viewer is a ruby gem that brings 3 concepts together:

1. Late binding for erb templates.
2. Declarative views/view models.
3. Dependancy management.

## Late bindings for erb

This allows you to go back in time and render values you'll calculate later into your templates. We wrap your code in a function and evaulate it once all of the other code in the template is finished. Here's a contextual example!

Sometimes when I'm writing templates or partials I want to include a little snippet of js (or css). I can use an inline `<script>` tag but then I end up with my rendered html being littered with `<script>` tags! Lets fix this.

```erb
<!-- templates/layouts/application.html.erb -->
<html>
 <head>
  <%-> @js.map { |js| "<script src=\"#{js}\"><script>" }.join("\t\t\n") %>
  <% @js = [] %>
 </head>
  <body>
    <%= yeild %>
  </body>
</html>
```

Here we're using an expression `@js.map { |js| "<script src=\"#{js}\"><script>" }.join("\t\t\n")` which will output a bunch of script tags. If it were evaualted then and there our `@js` variable would contain nothing and no tags would be outputted (or actually an error would occur because `@js = nil`). We're using some fancy syntax, `<%-> ... %>` which wraps the code in a function and evaluated later. This means we can fill our `@js` variable with strings which will turned into script tags and inserted into our `<head>` tag later!

```erb
<!-- templates/index.html.erb -->
<% @js << 'index.js' %>
<h1>Welcome to the Index Page!</h1>
```

In our template files we just add strings to the `@js` variable and trust that it will be rendered in out `<head>` tag later.

```html
<!-- After it's been rendered -->
<html>
  <head>
    <script src="index.js"></script>
  </head>
  <h1>Welcome to the Index Page!</h1>
</html>
```

This is what is rendered. It's not very impressive here but when you've for tens of files which dependencies that often change you no longer need to keep track of them in multiple places. Keep all the things that might change close together!

2. Declarative Views / View Models

String templating solves a big problem, rendering complex textual representations from complex data. The problem is, they are a lot like functions except without any explicit arguments! You have to read the whole template to know what it might require to render it. This makes templates hard to compose. Viewer includes a `View` class that you can extend with your own views, allowing you to be explict about the data that your views, layouts and partitals require. Heres an example!

```ruby
class Index < Viewer::View
  configure do |config|
    config.template = 'index'
  end

  def intialize(title)
    @title = title
  end

  expose :title do
    @title
  end
end
```

Here we're declaring a view object that has:

* a template located at `templates/index.html.erb` (this location isn't configurable yet and the extension is fixed).
* an `exposure` (a method / function / value) that is available in the view.
