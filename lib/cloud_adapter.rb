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
    @connection ||= begin
      logger.info 'Using SENEC_TOKEN to skip login' if config.senec_token

      Senec::Cloud::Connection.new(
        username: config.senec_username,
        password: config.senec_password,
        token: config.senec_token,
      )
    end
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
    systems.each do |system|
      logger.info "Found #{system}"
    end

    logger.info "Using first system, which is #{systems.first.id}"
    systems.first.id
  end

  SYSTEM = Struct.new(:id, :steuereinheitnummer, :gehaeusenummer) do
    def to_s
      "SENEC system #{id} (#{steuereinheitnummer}, #{gehaeusenummer})"
    end
  end

  def systems
    @systems ||= connection.systems.map do |system|
      SYSTEM.new(
        system['id'],
        system['steuereinheitnummer'],
        system['gehaeusenummer'],
      )
    end
  end

  def solectrus_record(id = 1)
    # Reset data cache to force a new request
    @dashboard_record = nil
    @technical_data_record = nil

    SolectrusRecord.new(id, record_hash).tap do |record|
      logger.info success_message(record)
    end
  rescue StandardError => e
    logger.error failure_message(e)
    nil
  end

  private

  def dashboard
    Senec::Cloud::Dashboard[connection].find(system_id)
  end

  def technical_data
    Senec::Cloud::TechnicalData[connection].find(system_id)
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
      bat_charge_current:,
      bat_voltage:,
      wallbox_charge_power:,
      ev_connected:,
      case_temp:,
      application_version:,
    }.compact
  end

  def record_hash
    raw_record_hash.except(*config.senec_ignore)
  end

  def dashboard_record
    @dashboard_record ||= dashboard.data
  end

  def technical_data_record
    @technical_data_record ||= technical_data.data
  end

  def measure_time
    Time.parse(dashboard_record['zeitstempel']).to_i
  end

  def inverter_power
    dashboard_record.dig('aktuell', 'stromerzeugung', 'wert')&.round
  end

  def house_power
    dashboard_record.dig('aktuell', 'stromverbrauch', 'wert')&.round
  end

  def wallbox_charge_power
    dashboard_record.dig('aktuell', 'wallbox', 'wert')&.round
  end

  def ev_connected
    dashboard_record['electricVehicleConnected'] == 'true'
  end

  def grid_power_minus
    dashboard_record.dig('aktuell', 'netzeinspeisung', 'wert')&.round
  end

  def grid_power_plus
    dashboard_record.dig('aktuell', 'netzbezug', 'wert')&.round
  end

  def bat_power_plus
    dashboard_record.dig('aktuell', 'speicherbeladung', 'wert')&.round
  end

  def bat_power_minus
    dashboard_record.dig('aktuell', 'speicherentnahme', 'wert')&.round
  end

  def bat_fuel_charge
    dashboard_record.dig('aktuell', 'speicherfuellstand', 'wert')&.round(1)
  end

  def bat_charge_current
    technical_data_record.dig('batteryPack', 'currentCurrentInA')&.round(2)
  end

  def bat_voltage
    technical_data_record.dig('batteryPack', 'currentVoltageInV')&.round(2)
  end

  def case_temp
    technical_data_record.dig('casing', 'temperatureInCelsius')&.round(1)
  end

  def application_version
    technical_data_record.dig('mcu', 'firmwareVersion')
  end

  def current_state
    raw_state = technical_data_record.dig('mcu', 'mainControllerState', 'name')
    return if raw_state == 'UNKNOWN'

    raw_state.tr('_', ' ')
  end

  # In German, because this seams to be language of the SENEC cloud
  # TODO: Maybe it is better to check for severity == 'INFO'
  OK_STATES = [
    'AKKU VOLL',
    'LADEN',
    'AKKU LEER',
    'ENTLADEN',
    'PV UND ENTLADEN',
    'NETZ UND ENTLADEN',
    'EIGENVERBRAUCH',
    'LADESCHLUSSPHASE',
    'PEAK SHAVING',
    'PEAK-SHAVING WARTEN',
    'AUFWACHLADUNG',
  ].freeze

  def current_state_ok
    return unless current_state

    OK_STATES.include? current_state
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
