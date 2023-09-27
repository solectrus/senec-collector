require 'test_helper'

class SenecStateNamesTest < Minitest::Test
  def test_fetch
    config = Config.from_env
    senec_state_names = SenecStateNames.new(config:)

    out, _err =
      capture_io do
        VCR.use_cassette('senec_state_names') do
          state_names = senec_state_names.fetch

          assert_equal (0..98).to_a, state_names.keys.sort
        end
      end

    assert_equal(
      "Getting state names (language: de) from SENEC by parsing source code...\nOK, got 99 state names\n",
      out,
    )
  end
end
