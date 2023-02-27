require 'test_helper'
require 'senec_pull'
require 'influx_push'
require 'config'
require 'solectrus_record'

class InfluxPushTest < Minitest::Test
  def test_single_record
    config = Config.from_env
    queue = Queue.new

    VCR.use_cassette('senec_success') { SenecPull.new(config:, queue:).run }

    assert_equal 1, queue.length

    VCR.use_cassette('influx_success') { InfluxPush.new(config:, queue:).run }

    assert_equal 0, queue.length
  end

  def test_multiple_record
    config = Config.from_env
    queue = Queue.new

    3.times do
      VCR.use_cassette('senec_success') { SenecPull.new(config:, queue:).run }
    end

    assert_equal 3, queue.length

    VCR.use_cassette('influx_success') { InfluxPush.new(config:, queue:).run }

    assert_equal 0, queue.length
  end

  def test_failure
    queue = Queue.new
    config = Config.from_env

    VCR.use_cassette('senec_success') { SenecPull.new(config:, queue:).run }

    assert_equal 1, queue.length

    FluxWriter.stub :push,
                    lambda { |_args|
                      raise InfluxDB2::InfluxError.new message: nil,
                                                       code: nil,
                                                       reference: nil,
                                                       retry_after: nil
                    } do
      assert_raises(InfluxDB2::InfluxError) do
        InfluxPush.new(config:, queue:).run
      end
    end

    assert_equal 1, queue.length
  end
end
