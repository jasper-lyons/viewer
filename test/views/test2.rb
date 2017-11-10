require_relative '../../lib/viewer.rb'

class Test2 < Viewer::View
  configure do |config|
    config.css << 'test2.css'
    config.js << 'test2.js'
    config.template = 'test2'
  end
end
