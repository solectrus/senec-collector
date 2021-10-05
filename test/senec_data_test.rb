require 'test_helper'
require 'senec_data'

class SenecDataTest < Minitest::Test
  def senec_host
    ENV.fetch('SENEC_HOST')
  end

  def test_success
    VCR.use_cassette('senec_success') do
      record = SenecData.new(senec_host).solectrus_record

      assert record.to_hash.is_a?(Hash)
    end
  end

  def test_failure
    VCR.use_cassette('senec_failure') do
      assert_raises Net::HTTPClientException do
        SenecData.new('example.com').solectrus_record.to_hash
      end
    end
  end
end
