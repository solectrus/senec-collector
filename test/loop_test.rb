require 'test_helper'

class LoopTest < Minitest::Test
  def config
    @config ||= Config.from_env
  end

  def test_start
    out, _err =
      capture_io do
        VCR.use_cassette('senec_success') do
          VCR.use_cassette('influx_success') do
            Loop.start(config:, max_count: 1)
          end
        end
      end

    assert_match(/Got record #1/, out)
  end
end
