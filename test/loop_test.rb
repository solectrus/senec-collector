require 'test_helper'
require 'loop'

class LoopTest < Minitest::Test
  def test_start
    VCR.use_cassette('senec_success') do
      VCR.use_cassette('influxdb') do
        Loop.start(max_count: 1)
      end
    end
  end
end
