require 'vcr'

SENSITIVE_DATA = [
  # Systems
  [0, 'id'],
  [0, 'steuereinheitnummer'],
  [0, 'gehaeusenummer'],
  [0, 'strasse'],
  [0, 'hausnummer'],
  [0, 'postleitzahl'],
  [0, 'ort'],
  # Technical data
  %w[systemOverview systemId],
  %w[systemOverview productName],
  %w[systemOverview installationDate],
  %w[casing serial],
  %w[mcu mainControllerSerial],
  %w[warranty endDate],
  %w[warranty warrantyTermInMonths],
  ['batteryModules', 0, 'serialNumber'],
  ['batteryModules', 1, 'serialNumber'],
  ['batteryModules', 2, 'serialNumber'],
  ['batteryModules', 3, 'serialNumber'],
  %w[installer companyName],
  %w[installer email],
  %w[installer phoneNumber],
  %w[installer address street],
  %w[installer address houseNumber],
  %w[installer address postcode],
  %w[installer address city],
  %w[installer address region],
  %w[installer address longitude],
  %w[installer address latitude],
  %w[installer website],
].freeze

VCR.configure do |config|
  config.cassette_library_dir = 'spec/cassettes'
  config.hook_into :faraday
  config.hook_into :webmock
  config.configure_rspec_metadata!

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
    SENEC_TOKEN
    SENEC_SYSTEM_ID
  ]
  sensitive_environment_variables.each do |key_name|
    config.filter_sensitive_data("<#{key_name}>") { ENV.fetch(key_name, nil) }
  end

  config.filter_sensitive_data('<TOKEN>') do |interaction|
    next unless interaction.senec_cloud?

    if interaction.response.body.include?('token')
      JSON.parse(interaction.response.body)['token']
    elsif interaction.request.headers.include?('Authorization')
      interaction.request.headers['Authorization'].first
    end
  end

  # :nocov:
  config.before_record do |interaction|
    next unless interaction.senec_cloud?

    # Bring back the original SENEC_SYSTEM_ID to the body. It will be replaced again later, but as String (not number)
    response_body = interaction.response.body.gsub('<SENEC_SYSTEM_ID>', ENV.fetch('SENEC_SYSTEM_ID'))

    json_data = begin
      JSON.parse(response_body)
    rescue JSON::ParserError
      nil
    end
    next unless json_data.is_a?(Hash) || json_data.is_a?(Array)

    SENSITIVE_DATA.each do |path|
      # Use dig to navigate to the target, but stop one level before the final key
      target = begin
        json_data.dig(*path[0...-1])
      rescue TypeError
        nil
      end

      # Check if we have an actual target to work with
      next unless target

      # Depending on the target's type, update it accordingly
      target[path.last] = if path.last == 'id'
                            '<SENEC_SYSTEM_ID>'
                          else
                            '<FILTERED>'
                          end
    end

    # Update the interaction response with the modified data
    interaction.response.body = json_data.to_json
  end
  # :nocov:

  record_mode = ENV['VCR'] ? ENV['VCR'].to_sym : :once
  config.default_cassette_options = {
    record: record_mode,
    allow_playback_repeats: true,
  }
end
