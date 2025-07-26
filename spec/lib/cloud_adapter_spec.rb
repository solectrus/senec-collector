require 'cloud_adapter'
require 'config'

describe CloudAdapter do
  subject(:adapter) { described_class.new(config:) }

  let(:config) do
    Config.from_env(senec_adapter: :cloud, senec_interval: 60, senec_system_id:)
  end
  let(:senec_system_id) { nil }

  let(:mock_systems) do
    [{ id: 999_999, controlUnitNumber: '999999', caseNumber: '123456' }]
  end

  let(:mock_dashboard) do
    {
      'currently' => {
        'powerGenerationInW' => 4200.0,
        'powerConsumptionInW' => 2300.0,
        'gridFeedInInW' => 1600.0,
        'gridDrawInW' => 100.0,
        'batteryChargeInW' => 0.0,
        'batteryDischargeInW' => 800.0,
        'batteryLevelInPercent' => 75.3,
        'selfSufficiencyInPercent' => 100.0,
        'wallboxInW' => 11_000.0,
      },
      'timestamp' => '2025-07-25T16:03:08Z',
      'electricVehicleConnected' => true,
      'systemId' => 999_999,
    }
  end

  let(:mock_system_details) do
    {
      'casing' => {
        'temperatureInCelsius' => 34.451965,
      },
      'mcu' => {
        'mainControllerUnitState' => {
          'name' => 'AKKU_VOLL',
          'severity' => 'INFO',
        },
        'firmwareVersion' => '826',
      },
    }
  end

  let(:mock_connection) do
    instance_double(
      Senec::Cloud::Connection,
      systems: mock_systems,
      dashboard: mock_dashboard,
      system_details: mock_system_details,
    )
  end

  before do
    config.logger = MemoryLogger.new

    allow(Senec::Cloud::Connection).to receive(:new).and_return(mock_connection)
  end

  describe '#initialize' do
    before { adapter }

    it do
      expect(config.logger.info_messages).to include(
        'Pulling from SENEC cloud every 60 seconds',
      )
    end
  end

  describe '#connection' do
    subject { adapter.connection }

    it { is_expected.to be(mock_connection) }
  end

  describe '#solectrus_record' do
    subject(:solectrus_record) { adapter.solectrus_record }

    shared_examples 'a SolectrusRecord' do
      it { is_expected.to be_a(SolectrusRecord) }

      it 'has an automatic id' do
        expect(solectrus_record.id).to eq(1)
      end

      it 'has a valid measure_time' do
        expect(solectrus_record.measure_time).to eq(1_753_459_388)
      end

      it 'has a valid inverter_power' do
        expect(solectrus_record.inverter_power).to eq(4200)
      end

      it 'has a valid house_power' do
        expect(solectrus_record.house_power).to eq(2300)
      end

      it 'has a valid grid_power_minus' do
        expect(solectrus_record.grid_power_minus).to eq(1600)
      end

      it 'has a valid grid_power_plus' do
        expect(solectrus_record.grid_power_plus).to eq(100)
      end

      it 'has a valid bat_power_minus' do
        expect(solectrus_record.bat_power_minus).to eq(800)
      end

      it 'has a valid bat_power_plus' do
        expect(solectrus_record.bat_power_plus).to eq(0)
      end

      it 'has a valid bat_fuel_charge' do
        expect(solectrus_record.bat_fuel_charge).to eq(75.3)
      end

      it 'has a valid wallbox_charge_power' do
        expect(solectrus_record.wallbox_charge_power).to eq(11_000)
      end

      it 'has a valid ev_connected' do
        expect(solectrus_record.ev_connected).to be(true)
      end

      it 'has a valid current_state' do
        expect(solectrus_record.current_state).to eq('AKKU VOLL')
      end

      it 'has a valid current_state_ok' do
        expect(solectrus_record.current_state_ok).to be(true)
      end

      it 'has a valid case_temp' do
        expect(solectrus_record.case_temp).to eq(34.5)
      end

      it 'has a valid application_version' do
        expect(solectrus_record.application_version).to eq('826')
      end

      context 'with senec_ignore' do
        let(:config) do
          Config.from_env(
            senec_adapter: :cloud,
            senec_ignore: 'wallbox_charge_power,house_power',
          )
        end

        it 'removes keys for ignored fields' do
          expect(solectrus_record.to_hash.keys).not_to include(
            :wallbox_charge_power,
            :house_power,
          )
        end

        it 'contains others' do
          expect(solectrus_record.to_hash.keys).to include(:inverter_power)
        end
      end
    end

    it_behaves_like 'a SolectrusRecord'
  end
end
