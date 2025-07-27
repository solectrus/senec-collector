require 'solectrus_record'
require 'forwardable'

class CloudAdapter
  extend Forwardable

  def_delegators :config, :logger

  def initialize(config:)
    @config = config

    logger.info "Pulling from SENEC cloud every #{config.senec_interval} seconds"

    case config.senec_request_mode
    when :minimal
      logger.info 'SENEC_REQUEST_MODE is set to "minimal", so we send just one API request each time'
    when :full
      logger.info 'SENEC_REQUEST_MODE is set to "full", so we send two API requests each time to get additional data'
    end
  end

  attr_reader :config

  def connection
    @connection ||=
      Senec::Cloud::Connection.new(
        username: config.senec_username,
        password: config.senec_password,
        user_agent:,
      )
  end

  def user_agent
    app = 'SENEC-Collector'
    version = ENV.fetch('VERSION', nil)
    identifier = [app, version].compact.join('/')

    "#{identifier} (+https://github.com/solectrus/senec-collector)"
  end

  def system
    @system ||=
      begin
        raise 'No systems found' if systems.empty?

        log_available_systems
        find_system || raise('System not found!')
      end
  end

  def solectrus_record(id = 1)
    # Reset data cache to force a new request
    @dashboard = nil
    @system_details = nil

    SolectrusRecord
      .new(id, record_hash)
      .tap { |record| logger.info success_message(record) }
  rescue StandardError => e
    logger.error failure_message(e)
    nil
  end

  private

  def systems
    @systems ||= connection.systems
  end

  def log_available_systems
    logger.info "\nAvailable systems:"
    systems.each do |system|
      logger.info "- #{system['id']} (#{system['controlUnitNumber']}, #{system['caseNumber']})"
    end
  end

  def find_system
    if config.senec_system_id
      logger.info "Using SENEC_SYSTEM_ID #{config.senec_system_id}"

      systems.find { |s| s['id'].to_s == config.senec_system_id }
    else
      first_system = systems.first
      logger.info "No SENEC_SYSTEM_ID given, using first available system (#{first_system['id']})"

      first_system
    end
  end

  def dashboard
    @dashboard ||= connection.dashboard(system['id'])
  end

  def system_details
    @system_details ||=
      case config.senec_request_mode
      when :minimal
        {}
      when :full
        connection.system_details(system['id'])
      end
  end

  def wallboxes
    @wallboxes ||=
      system['wallboxIds'].sort.map do |wallbox_id|
        connection.wallbox(system['id'], wallbox_id)
      end
  end

  def home4_wallbox?
    system['wallboxIds']&.any? do |wallbox_id|
      # For V3, the ids are simple numbers as string, like "1", "2", etc.
      # For Home.4 the ids are UUIDv4 like "abcdef12-1234-42ab-84de-abcdef123456"
      wallbox_id.include?('-')
    end
  end

  def raw_record_hash
    {
      current_state:,
      current_state_ok:,
      measure_time:,
      inverter_power:,
      house_power:,
      grid_power_minus:,
      grid_power_plus:,
      bat_power_minus:,
      bat_power_plus:,
      bat_fuel_charge:,
      wallbox_charge_power:,
      ev_connected:,
      case_temp:,
      application_version:,
    }.compact
  end

  def record_hash
    raw_record_hash.except(*config.senec_ignore)
  end

  def measure_time
    Time.parse(dashboard['timestamp']).to_i
  end

  def inverter_power
    dashboard.dig('currently', 'powerGenerationInW')&.round
  end

  def house_power
    consumption = dashboard.dig('currently', 'powerConsumptionInW')&.round

    if consumption && home4_wallbox?
      [consumption - (wallbox_charge_power || 0), 0].max
    else
      consumption
    end
  end

  def wallbox_charge_power
    if home4_wallbox?
      # Separate request needed for each wallbox
      wallboxes
        &.filter_map do |wallbox|
          power_in_kw =
            wallbox.dig('chargingCurrents', 'currentApparentChargingPowerInKw')

          (power_in_kw * 1000).round if power_in_kw
        end
        &.sum
    else
      # Total is already available in the dashboard
      dashboard.dig('currently', 'wallboxInW')&.round
    end
  end

  def ev_connected
    dashboard['electricVehicleConnected']
  end

  def grid_power_minus
    dashboard.dig('currently', 'gridFeedInInW')&.round
  end

  def grid_power_plus
    dashboard.dig('currently', 'gridDrawInW')&.round
  end

  def bat_power_plus
    dashboard.dig('currently', 'batteryChargeInW')&.round
  end

  def bat_power_minus
    dashboard.dig('currently', 'batteryDischargeInW')&.round
  end

  def bat_fuel_charge
    dashboard.dig('currently', 'batteryLevelInPercent')&.round(1)
  end

  def case_temp
    system_details.dig('casing', 'temperatureInCelsius')&.round(1)
  end

  def application_version
    system_details.dig('mcu', 'firmwareVersion')
  end

  def current_state
    raw_state = system_details.dig('mcu', 'mainControllerUnitState', 'name')

    # The Home.4 has two states that are not useful
    return if ['UNKNOWN', 'RUN_GRID', nil].include?(raw_state)

    raw_state.tr('_', ' ')
  end

  def current_state_ok
    severity = system_details.dig('mcu', 'mainControllerUnitState', 'severity')
    return if severity.nil?

    severity == 'INFO'
  end

  def success_message(record)
    [
      "\nGot record ##{record.id} at " \
      "#{Time.at(record.measure_time).localtime}",
      record.current_state || 'Unknown state',
      ("Inverter #{record.inverter_power} W" unless config.excludes?(:inverter_power)),
      ("House #{record.house_power} W" unless config.excludes?(:house_power)),
      ("Wallbox #{record.wallbox_charge_power} W" unless config.excludes?(:wallbox_charge_power)),
    ].compact.join(', ')
  end

  def failure_message(error)
    "Error getting data from SENEC cloud: #{error}"
  end
end
