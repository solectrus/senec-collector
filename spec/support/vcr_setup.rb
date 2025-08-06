require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/cassettes'
  config.hook_into :faraday
  config.hook_into :webmock
  config.configure_rspec_metadata!

  sensitive_environment_variables = %w[
    INFLUX_HOST
    INFLUX_TOKEN
    INFLUX_ORG
    INFLUX_BUCKET
    SENEC_HOST
    SENEC_USERNAME
    SENEC_PASSWORD
    SENEC_TOTP_URI
    SENEC_SYSTEM_ID
  ]
  sensitive_environment_variables.each do |key_name|
    config.filter_sensitive_data("<#{key_name}>") { ENV.fetch(key_name, nil) }
  end

  record_mode = ENV['VCR'] ? ENV['VCR'].to_sym : :once
  config.default_cassette_options = {
    record: record_mode,
    allow_playback_repeats: true,
  }
end

# Disable VCR when a WebMock stub is created
# https://github.com/vcr/vcr/issues/146#issuecomment-573217860
RSpec.configure do |config|
  WebMock::API.prepend(Module.new do
    extend self

    # disable VCR when a WebMock stub is created
    # for clearer spec failure messaging
    def stub_request(*args)
      VCR.turn_off!
      super
    end
  end)

  config.before { VCR.turn_on! }
end
