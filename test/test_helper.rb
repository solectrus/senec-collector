require 'minitest/autorun'
require 'webmock/minitest'

require File.expand_path './support/vcr_setup.rb', __dir__

require 'config'
Config.class_eval do
  # Stub the state names to avoid having to mock the Senec API
  def senec_state_names
    { 0 => 'INIT', 14 => 'LADEN', 16 => 'ENTLADEN' }
  end
end
