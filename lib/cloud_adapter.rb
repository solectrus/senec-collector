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
    @connection ||= Senec::Cloud::Connection.new(
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
        logger.info 'Using SENEC_SYSTEM_ID 0'
        0
      end
  end

  def solectrus_record(id = 1)
    # Reset data cache to force a new request
    @stats_overview_data = nil
    @wallboxes_data = nil

    SolectrusRecord.new(id, record_hash).tap do |record|
      logger.info success_message(record)
    end
  rescue StandardError => e
    logger.error failure_message(e)
    nil
  end

  private

  def stats_overview
    Senec::Cloud::StatsOverview.new(connection:, system_id:)
  end

  def wallboxes
    Senec::Cloud::Wallboxes.new(connection:, system_id:)
  end

  def raw_record_hash # rubocop:disable Metrics/AbcSize
    {
      current_state:,
      current_state_code:,
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
      wallbox_charge_power0:,
      wallbox_charge_power1:,
      wallbox_charge_power2:,
      wallbox_charge_power3:,
      ev_connected:,
      application_version:,
    }.compact
  end

  def record_hash
    raw_record_hash.except(*config.senec_ignore)
  end

  def stats_overview_data
    @stats_overview_data ||= stats_overview.data
  end

  def wallboxes_data
    @wallboxes_data ||= wallboxes.data
  end

  def measure_time
    stats_overview_data['lastupdated']
  end

  def inverter_power
    (stats_overview_data.dig('powergenerated', 'now') * 1000).round
  end

  def house_power
    [
      (stats_overview_data.dig('consumption', 'now') * 1000).round - (wallbox_charge_power || 0),
      0,
    ].max
  end

  def wallbox_charge_power
    return unless wallboxes_data.any?

    [
      wallbox_charge_power0,
      wallbox_charge_power1,
      wallbox_charge_power2,
      wallbox_charge_power3,
    ].compact.sum
  end

  [0, 1, 2, 3].each do |i|
    define_method("wallbox_charge_power#{i}") do
      return unless wallboxes_data.any?

      wallboxes_data.dig(i, 'currentApparentChargingPowerInVa')
    end
  end

  def ev_connected
    return unless wallboxes_data.any?

    wallboxes_data.first['electricVehicleConnected']
  end

  def grid_power_minus
    (stats_overview_data.dig('gridexport', 'now') * 1000).round
  end

  def grid_power_plus
    (stats_overview_data.dig('gridimport', 'now') * 1000).round
  end

  def bat_power_plus
    (stats_overview_data.dig('accuimport', 'now') * 1000).round
  end

  def bat_power_minus
    (stats_overview_data.dig('accuexport', 'now') * 1000).round
  end

  def bat_fuel_charge
    stats_overview_data.dig('acculevel', 'now')&.round(1)
  end

  def application_version
    stats_overview_data['firmwareVersion']
  end

  def current_state
    raw_state = stats_overview_data['steuereinheitState']
    return if raw_state == 'UNKNOWN'

    raw_state.tr('_', ' ')
  end

  def current_state_code
    stats_overview_data['state']
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
  private_constant :OK_STATES

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
