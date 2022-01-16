require 'test_helper'
require 'senec_pull'
require 'config'

class SenecPullTest < Minitest::Test
  def test_success
    queue = Queue.new
    config = Config.from_env

    VCR.use_cassette('senec_success') do
      SenecPull.new(config:, queue:).run
    end

    assert_equal 1, queue.length
  end

  def test_failure
    queue = Queue.new
    config = Config.from_env(senec_host: 'example.com')

    VCR.use_cassette('senec_failure') do
      assert_raises(Net::HTTPClientException) do
        SenecPull.new(config:, queue:).run
      end
    end

    assert_equal 0, queue.length
  end
end
