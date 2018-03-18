# Viewer
> Only load the js and css that you need for each page.

Viewer is a ruby gem that brings 3 concepts together:

1. Late binding for erb templates.
2. Declarative views/view models.
3. Dependancy management.

## Late bindings for erb

This allows you to go back in time and render values you'll calculate later into your templates. We wrap your code in a function and evaluate it once all of the other code in the template is finished. Here's a contextual example!

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

Here we're using an expression `@js.map { |js| "<script src=\"#{js}\"><script>" }.join("\t\t\n")` which will output a bunch of script tags. If it were evaluated then and there our `@js` variable would contain nothing and no tags would be outputted (or actually an error would occur because `@js = nil`). We're using some fancy syntax, `<%-> ... %>` which wraps the code in a function and evaluated later. This means we can fill our `@js` variable with strings which will turned into script tags and inserted into our `<head>` tag later!

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

## Declarative Views / View Models

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

We can then use the `title` exposure as a method in the template, like so:

```erb
<h1><%= title %></h1>
```

Now if we instantiate an `Index` object with a string and call the `Index#render` function we'll get the string we passed in as the title in the `<h1>` tag.

## Dependancy management

Now we can tie the previous two concepts together. Firstly, all `Viewer::View` subclasses expose a `js` and `css` method which can be called in the template. You can set js and css files to use in the config block of the subclass, like so:

```ruby
class Index < Viewer::View
  configure do |config|
    config.js << 'index.js'
    config.css << 'index.css'
    config.template = 'index'
  end
end
```

Now even without the late binding we can render our js and css dependencies as scripts as easily as `<%= js %>` (no late binding required as the depedencies were declared before the template is being evaluated)  and the `Viewer::JSRenderer` class will write some pretty `<script>` tags for you. But what about if we want to compose View Models? Perhaps like this?

```ruby
class Index < Viewer::View
  ...
end

class Header < Viewer::View
  configure do |config|
    config.css << 'header'
    config.template = 'partial/header'
  end
end

class Footer < Viewer::View
  configure do |config|
    config.css << 'footer'
    config.template = 'partial/footer'
  end
end
```

And we used them in a template like this:

```erb
<!-- templates/index.html.erb -->
<html>
  <head>
    <%-> css %>
    <%-> js %>
  </head>
  <body>
    <%= Header.new(title) %>
    <p>Isn't this nice!</p>
    <%= Footer.new %>
  </body>
</html>
```

The dependencies from `Header` and `Footer` are included! This is because we have a `hook` method that is called for every value being rendered into the template (every time you use `<%= ... %>`) that checks to see if the value is a `Viewer::View` and if it is, it calls the `register` function on it. This means that the the sub view's js and css dependencies are added to the calling views js and css dependencies list. That means that, because our `js` and `css` methods are late bound to the template, they will contain all of the dependencies for all of the views used to render the template!
