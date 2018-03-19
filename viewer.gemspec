# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'viewer/version'

Gem::Specification.new do |spec|
  spec.name          = "viewer"
  spec.version       = Viewer::VERSION
  spec.authors       = ["Jasper Lyons"]
  spec.email         = ["jasper.lyons@gmail.com"]

  spec.summary       = %q{Only load the js and css that you need for each page.}
  spec.description   = %q{Composable ERB views with late binding, declarative view models and dependency management.}
  spec.homepage      = "https://github.com/jasper-lyons/viewer"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "tilt"

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
end
