require 'solectrus_record'
require 'forwardable'

class CloudAdapter
  extend Forwardable

  def_delegators :config, :logger

  def initialize(config:)
    @config = config

    logger.info "Pulling from SENEC cloud every #{config.senec_interval} seconds"
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

  def system_id
    @system_id ||=
      if config.senec_system_id
        logger.info "Using SENEC_SYSTEM_ID #{config.senec_system_id}"
        config.senec_system_id
      else
        determine_system
      end
  end

  def determine_system
    logger.info 'No SENEC_SYSTEM_ID given, looking for existing systems...'
    systems.each { |system| logger.info "Found #{system}" }

    logger.info "Using first system, which is #{systems.first.id}"
    systems.first.id
  end

  SYSTEM =
    Struct.new(:id, :control_unit_number, :case_number) do
      def to_s
        "SENEC system #{id} (#{control_unit_number}, #{case_number})"
      end
    end

  def systems
    @systems ||=
      connection.systems.map do |system|
        SYSTEM.new(
          system['id'],
          system['controlUnitNumber'],
          system['caseNumber'],
        )
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

  def dashboard
    @dashboard ||= connection.dashboard(system_id)
  end

  def system_details
    @system_details ||= connection.system_details(system_id)
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
    dashboard.dig('currently', 'powerConsumptionInW')&.round
  end

  def wallbox_charge_power
    dashboard.dig('currently', 'wallboxInW')&.round
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

    # The Home.4 has two states that are not useful for us
    return if %w[UNKNOWN RUN_GRID].include?(raw_state)

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
