require 'simplecov'
SimpleCov.start

require 'minitest/autorun'
require 'webmock/minitest'
require 'loop'
require 'config'

require File.expand_path './support/vcr_setup.rb', __dir__
