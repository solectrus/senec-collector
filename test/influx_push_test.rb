require 'test_helper'
require 'senec_pull'
require 'influx_push'
require 'config'
require 'solectrus_record'

class InfluxPushTest < Minitest::Test
  def config
    @config ||= Config.from_env
  end

  def queue
    @queue ||= Queue.new
  end

  def test_single_record
    fill_queue

    assert_success do
      thread =
        Thread.new do
          VCR.use_cassette('influx_success') do
            InfluxPush.new(config:, queue:).run
          end
        end

      Timeout.timeout(3) { loop until queue.empty? }
      queue.close
      thread.join
    end
  end

  def test_multiple_records
    fill_queue(3)

    assert_success do
      thread =
        Thread.new do
          VCR.use_cassette('influx_success') do
            InfluxPush.new(config:, queue:).run
          end
        end

      Timeout.timeout(3) { loop until queue.empty? }
      queue.close
      thread.join
    end
  end

  def test_failure
    fill_queue

    assert_failure(1) do
      FluxWriter.stub :new, FailingFluxWriter.new do
        thread = Thread.new { InfluxPush.new(config:, queue:).run }

        sleep(1)
        queue.close
        thread.join
      end
    end
  end

  def fill_queue(num_records = 1)
    num_records.times do
      VCR.use_cassette('senec_success') { SenecPull.new(config:, queue:).run }
    end

    assert_equal num_records, queue.length
  end

  def assert_success(&block)
    out, _err = capture_io { yield(block) }

    assert_equal 0, queue.length
    assert_match(/Successfully pushed record to InfluxDB/, out)
  end

  def assert_failure(num_records, &block)
    out, _err = capture_io { yield(block) }

    assert_equal num_records, queue.length
    assert_match(/Error while pushing record to InfluxDB/, out)
  end

  class FailingFluxWriter
    def push(_record)
      raise InfluxDB2::InfluxError.new message: nil,
                                       code: nil,
                                       reference: nil,
                                       retry_after: nil
    end
  end
end
