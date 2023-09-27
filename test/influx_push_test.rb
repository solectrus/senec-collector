require 'test_helper'

class InfluxPushTest < Minitest::Test
  def test_single_record
    fill_queue

    assert_success do
      thread =
        Thread.new do
          VCR.use_cassette('influx_success') do
            InfluxPush.new(config:, queue:).run
          end
        end

      # Wait for the queue to be empty (or timeout)
      Timeout.timeout(3) { loop until queue.empty? }

      queue.close
      thread.join
    end
  end

  def test_multiple_records
    fill_queue(3)

    assert_success(3) do
      thread =
        Thread.new do
          VCR.use_cassette('influx_success') do
            InfluxPush.new(config:, queue:).run
          end
        end

      # Wait for the queue to be empty (or timeout)
      Timeout.timeout(1) { loop until queue.empty? }

      queue.close
      thread.join
    end
  end

  def test_failure
    fill_queue

    assert_failure(1) do
      FluxWriter.stub :new, FailingFluxWriter.new do
        thread = Thread.new { InfluxPush.new(config:, queue:).run }

        # Wait a bit for the thread to fail
        sleep(1)

        queue.close
        thread.join
      end
    end
  end

  private

  def config
    @config ||= Config.from_env
  end

  def queue
    @queue ||= Queue.new
  end

  def senec_pull
    @senec_pull ||=
      begin
        senec_pull = SenecPull.new(config:, queue:)
        capture_io do
          VCR.use_cassette('senec_state_names') { senec_pull.senec_state_names }
        end

        senec_pull
      end
  end

  def fill_queue(num_records = 1)
    num_records.times { VCR.use_cassette('senec_success') { senec_pull.next } }

    assert_equal num_records, queue.length
  end

  def assert_success(num_records = 1, &block)
    out, _err = capture_io { yield(block) }

    assert_equal 0, queue.length
    assert_equal(
      (1..num_records)
        .map { |i| "Successfully pushed record ##{i} to InfluxDB\n" }
        .join,
      out,
    )
  end

  def assert_failure(num_records, &block)
    out, _err = capture_io { yield(block) }

    assert_equal num_records, queue.length
    assert_match(/Error while pushing record #1 to InfluxDB/, out)
  end
end

class FailingFluxWriter
  def push(_record)
    raise InfluxDB2::InfluxError.new message: nil,
                                     code: nil,
                                     reference: nil,
                                     retry_after: nil
  end
end
