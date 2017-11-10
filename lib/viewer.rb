require 'tilt'
require 'set'

module Templates
  class Renderer < Tilt::Template
    EMBEDDED_PATTERN = /<%(=+|\#)?(.*?)-?%>/m

    def prepare
      @src = convert(data)
    end

    def convert(input)
      src = "_buf = ''\n"           # preamble
      pos = 0
      input.scan(EMBEDDED_PATTERN) do |indicator, code|
        m = Regexp.last_match
        text = input[pos...m.begin(0)]
        pos  = m.end(0)
        #src << " _buf << '" << escape_text(text) << "';"
        text.gsub!(/['\\]/, '\\\\\&')
        src << " _buf << '" << text << "'\n" unless text.empty?
        if !indicator              # <% %>
          src << code << "\n"
        elsif indicator == '#'     # <%# %>
          src << ("\n" * code.count("\n"))
        else                       # <%= %>
          src << " _buf << (respond_to?(:hook) ? hook(\"" << code << "\", binding).to_s : (" << code << ").to_s)\n"
        end
      end
      #rest = $' || input                        # ruby1.8
      rest = pos == 0 ? input : input[pos..-1]   # ruby1.9
      #src << " _buf << '" << escape_text(rest) << "';"
      rest.gsub!(/['\\]/, '\\\\\&')
      src << " _buf << '" << rest << "'\n" unless rest.empty?
      src << "\n_buf.to_s\n"       # postamble
      return src
    end

    def result(_binding=binding)
      eval @src, _binding
    end

    def evaluate(_context=self)
      if _context.is_a?(Hash)
        _obj = Object.new
        _context.each do |k, v| _obj.instance_variable_set("@#{k}", v) end
        _context = _obj
      end
      _context.instance_eval @src
    end

    alias :render :evaluate
  end

  class Context
    class << self
      attr_writer :exposures
      attr_accessor :default
      def exposures
        @exposures ||= Hash.new { |h,k| h[k] = {} }
      end

      def inherited(base)
        # perform a deep merge of the exposures hash
        base.exposures.merge!(exposures.map do |k,v|
          [k, v.dup]
        end.to_h)

        base.default = self.default
      end

      def expose(name, value = nil, &block)
        exposures[name][:method] = name
        exposures[name][:value] = value if value

        unless method_defined?(name)
          define_method(name) do
            # allow values to be overriden by subclasses
            value = self.class.exposures[name][:value] || name
            block = block || self.class.default
            byebug unless block
            instance_exec(value, &block)
          end
        end
      end

      def describe(name, description)
        exposures[name][:description] = description
      end

      def default(&block)
        @default = block || @default
      end
    end
  end
end

Tilt.register Templates::Renderer, 'erb'

module Viewer
  class CSSRenderer < Set
    def to_s
      map { |e| "<link rel=\"stylesheet\" type=\"text/css\" href=\"#{e}\">" }.join("\n")
    end
  end
  class JSRenderer < Set
    def to_s
      map { |e| "<script src=#{e}></script>" }.join("\n")
    end
  end

  class View < Templates::Context
    DEFAULT_LAYOUT = 'layout'
    DEFAULT_RENDERER = 'erb'
    Config = Struct.new(:template, :theme, :layout, :css, :js)

    class << self
      def configure
        yield(config)
      end

      def config
        @config ||= Config.new.tap do |config|
          config.css = CSSRenderer.new
          config.js = JSRenderer.new
        end
      end
      attr_writer :config

      def inherited(base)
        base.config = self.config.dup
        base.config.css = self.config.css.dup
        base.config.js = self.config.js.dup
      end

      def register(view)
        config.css += view.config.css
        config.js += view.config.js
      end
    end
    
    def initialize(template: nil, theme: nil, layout: nil, css: nil, js: nil)
      @template = template || self.class.config.template
      @theme = theme || self.class.config.theme
      @layout = layout || self.class.config.layout || DEFAULT_LAYOUT
      @css = self.class.config.css
      @js = self.class.config.js
    end

    attr_reader :template, :theme, :layout

    def templates_path_list
      ['templates', theme].compact
    end

    def template_path
      File.join(*templates_path_list, "#{template}.html.#{DEFAULT_RENDERER}")
    end

    def layout_path
      File.join(*templates_path_list, "#{layout}.html.#{DEFAULT_RENDERER}")
    end

    def register(view)
      @css += view.css
      @js += view.js
    end

    # introduce a compile step
    # and a simple render step
    def hook(code, binding)
      value = eval(code, binding) 
      if value.is_a?(Viewer::View)
        register(value)
      end
      lambdas << -> { eval(code, binding) }
      '%s'
    end

    def lambdas
      @lambdas ||= []
    end

    def compile(context: self, encoding: 'utf-8')
      layout_renderer = if File.exists?(layout_path)
        Tilt.new(layout_path, default_encoding: encoding)
      end

      template_renderer = Tilt.new(template_path, default_encoding: encoding)


      @compiled_template = if layout_renderer
        layout_renderer.render(context) do
          template_renderer.render(context)
        end
      else
        template_renderer.render(context)
      end
    end

    def compiled_template
      @compiled_template ||= ""
    end

    def render(context: self, encoding: 'utf-8')
      template = compile(context: context, encoding: encoding)
      format(template, *lambdas.map(&:call))
    end

    alias :to_s :render

    expose :css do
      @css
    end

    expose :js do
      @js
    end
  end
end
