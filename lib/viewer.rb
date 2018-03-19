require 'viewer/version'
require 'tilt'
require 'set'

module Templates
  class Renderer < Tilt::Template
    EMBEDDED_PATTERN = /<(%->|%=+|%\#|%)(.*?)-?%>/m

    def prepare
      @src = convert(data)
    end

    def convert(input)
      src = <<~RUBY
      late_bindings = []
      buffer = ""
      #{
        input.split(EMBEDDED_PATTERN).
          each_slice(3).
          map { |text, type, code| dispatch_codegenerator(text, type, code) }.
          join
      }
      if late_bindings.empty?
        return buffer
      else
        return format(buffer, *late_bindings.map(&:call))
      end
      RUBY
      src
    end

    def precompiled_template(locals)
      @src
    end

    private

    def dispatch_codegenerator(text, type, code)
      case type
      when '%'
        generate_code(text, code)
      when '%#', nil
        generate_comment(text)
      when '%='
        generate_value_code(text, code)
      when '%->'
        generate_late_bound_code(text, code)
      else
        generate_error(text, type)
      end
    end

    def generate_code(text, code)
      <<~RUBY
        buffer << #{text.rstrip.inspect}
        #{code}
      RUBY
    end

    def generate_comment(text)
      <<~RUBY
        buffer << #{text.rstrip.inspect}
      RUBY
    end

    def generate_value_code(text, code)
      <<~RUBY
        buffer << #{text.inspect}
        buffer << (respond_to?(:hook) ? hook(#{code}) : #{code}).to_s
      RUBY
    end

    def generate_late_bound_code(text, code)
      <<~RUBY
        buffer << #{text.inspect}
        late_bindings << -> { (#{code}).to_s }
        buffer << '%s'
      RUBY
    end

    def generate_error(text, type)
      <<~RUBY
        buffer << #{text.inspect}
        raise \"Unexpected indicator #{type}\"
      RUBY
    end
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

    def hook(value)
      value.tap { |v| register(v) if v.is_a?(Viewer::View) }
    end

    def lambdas
      @lambdas ||= []
    end

    def render(context: self, encoding: 'utf-8')
      layout_renderer = if File.exists?(layout_path)
                          Tilt.new(layout_path, default_encoding: encoding)
                        end

      template_renderer = Tilt.new(template_path, default_encoding: encoding)


      if layout_renderer
        layout_renderer.render(context) do
          template_renderer.render(context)
        end
      else
        template_renderer.render(context)
      end
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
