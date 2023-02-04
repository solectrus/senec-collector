require 'test_helper'
require 'loop'
require 'config'

class LoopTest < Minitest::Test
  def test_start
    config = Config.from_env

    VCR.use_cassette('senec_success') do
      VCR.use_cassette('influx_success') do
        out, err = capture_io { Loop.start(config:, max_count: 1) }

        assert_match(/Got record #1 from SENEC/, out)
        assert_equal('', err)
      end
    end
  end
end
