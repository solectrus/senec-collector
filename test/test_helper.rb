require 'simplecov'
SimpleCov.start

require 'minitest/autorun'
require 'webmock/minitest'
require 'loop'
require 'config'

require File.expand_path './support/vcr_setup.rb', __dir__

# Stub the state names to avoid having to mock the Senec API
module StubStateNames
  def senec_state_names
    { 0 => 'INIT', 14 => 'LADEN', 16 => 'ENTLADEN' }
  end
end

class Config
  prepend StubStateNames
end
###################
