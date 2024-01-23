require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/cassettes'
  config.hook_into :faraday
  config.hook_into :webmock

  VCR::HTTPInteraction::HookAware.class_eval do
    def senec_cloud?
      request.uri.include?('senec.dev')
    end
  end

  sensitive_environment_variables = %w[
    INFLUX_HOST
    INFLUX_TOKEN
    INFLUX_ORG
    INFLUX_BUCKET
    SENEC_HOST
    SENEC_USERNAME
    SENEC_PASSWORD
    SENEC_SYSTEM_ID
  ]
  sensitive_environment_variables.each do |key_name|
    config.filter_sensitive_data("<#{key_name}>") { ENV.fetch(key_name) }
  end

  config.filter_sensitive_data('<TOKEN>') do |interaction|
    next unless interaction.senec_cloud?

    if interaction.response.body.include?('token')
      JSON.parse(interaction.response.body)['token']
    elsif interaction.request.headers.include?('Authorization')
      interaction.request.headers['Authorization'].first
    end
  end

  %w[
    steuereinheitnummer
    gehaeusenummer
    strasse
    hausnummer
    postleitzahl
    ort
  ].each do |key|
    config.filter_sensitive_data("<#{key}>") do |interaction|
      next unless interaction.senec_cloud?

      JSON.parse(interaction.response.body).first[key] if interaction.response.body.include?("\"#{key}\"")
    end
  end

  config.filter_sensitive_data('<SENEC_SYSTEM_ID>') do |interaction|
    next unless interaction.senec_cloud?

    JSON.parse(interaction.response.body).first['id'] if interaction.response.body.include?('id')
  end

  record_mode = ENV['VCR'] ? ENV['VCR'].to_sym : :once
  config.default_cassette_options = {
    record: record_mode,
    allow_playback_repeats: true,
  }
end
