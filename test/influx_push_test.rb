require 'test_helper'
require 'senec_pull'
require 'influx_push'
require 'config'
require 'solectrus_record'

class InfluxPushTest < Minitest::Test
  def test_single_record
    config = Config.from_env
    queue = Queue.new

    VCR.use_cassette('senec_success') do
      SenecPull.new(config:, queue:).run
    end

    assert_equal 1, queue.length

    VCR.use_cassette('influx_success') do
      InfluxPush.new(config:, queue:).run
    end

    assert_equal 0, queue.length
  end

  def test_multiple_record
    config = Config.from_env
    queue = Queue.new

    3.times do
      VCR.use_cassette('senec_success') do
        SenecPull.new(config:, queue:).run
      end
    end
    assert_equal 3, queue.length

    VCR.use_cassette('influx_success') do
      InfluxPush.new(config:, queue:).run
    end

    assert_equal 0, queue.length
  end

  def test_failure
    queue = Queue.new
    config = Config.from_env(influx_host: 'example.com')

    VCR.use_cassette('senec_success') do
      SenecPull.new(config:, queue:).run
    end

    assert_equal 1, queue.length

    VCR.use_cassette('influx_failure') do
      assert_raises(InfluxDB2::InfluxError) do
        InfluxPush.new(config:, queue:).run
      end
    end

    assert_equal 1, queue.length
  end
end
