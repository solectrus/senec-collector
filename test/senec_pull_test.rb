require 'test_helper'
require 'senec_pull'
require 'config'

class SenecPullTest < Minitest::Test
  def test_success
    queue = Queue.new
    config = Config.from_env

    VCR.use_cassette('senec_success') { SenecPull.new(config:, queue:).run }

    assert_equal 1, queue.length
  end

  def test_failure
    queue = Queue.new
    config = Config.from_env

    Senec::Request.stub :new, ->(_args) { raise Senec::Error } do
      assert_raises(Senec::Error) { SenecPull.new(config:, queue:).run }
    end

    assert_equal 0, queue.length
  end
end
