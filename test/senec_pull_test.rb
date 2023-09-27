require 'test_helper'

class SenecPullTest < Minitest::Test
  def test_success
    VCR.use_cassette('senec_success') { senec_pull.next }

    assert_equal 1, queue.length
  end

  def test_failure
    Senec::Request.stub :new, ->(_args) { raise Senec::Error } do
      assert_raises(Senec::Error) { senec_pull.next }
    end

    assert_equal 0, queue.length
  end

  private

  def queue
    @queue ||= Queue.new
  end

  def config
    @config ||= Config.from_env
  end

  def senec_pull
    SenecPull
      .new(config:, queue:)
      .tap do |senec_pull|
        capture_io do
          VCR.use_cassette('senec_state_names') { senec_pull.senec_state_names }
        end
      end
  end
end
