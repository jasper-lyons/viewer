require_relative '../../lib/viewer.rb'
require_relative './test2.rb'

class Test < Viewer::View
  configure do |config|
    config.css << 'test.css'
    config.template = 'test'
  end
end
