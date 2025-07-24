require 'cloud_adapter'
require 'config'

describe CloudAdapter do
  subject(:adapter) do
    described_class.new(config:)
  end

  let(:config) { Config.from_env(senec_adapter: :cloud, senec_interval: 60, senec_system_id:) }
  let(:senec_system_id) { nil }

  # Mock data for SENEC cloud responses - sunny day scenario
  let(:mock_stats_overview_data) do
    {
      'lastupdated' => 1_700_000_000,
      'powergenerated' => { 'now' => 4.2 }, # 4200W PV generation
      'consumption' => { 'now' => 13.3 }, # 13300W total consumption (including wallbox)
      'gridexport' => { 'now' => 1.6 }, # 1600W export to grid
      'gridimport' => { 'now' => 0.1 }, # 100W minimal grid import
      'accuimport' => { 'now' => 0.8 }, # 800W battery charging
      'accuexport' => { 'now' => 0.0 }, # No battery discharging
      'acculevel' => { 'now' => 75.3 }, # 75.3% SOC
      'steuereinheitState' => 'LADEN',
      'firmwareVersion' => 826,
    }
  end

  let(:mock_wallboxes_data) do
    [
      {
        'currentApparentChargingPowerInVa' => 11_000, # 11kW wallbox charging
        'electricVehicleConnected' => true,
      },
    ]
  end

  let(:mock_connection) { instance_double(Senec::Cloud::Connection) }
  let(:mock_stats_overview) { instance_double(Senec::Cloud::StatsOverview, data: mock_stats_overview_data) }
  let(:mock_wallboxes) { instance_double(Senec::Cloud::Wallboxes, data: mock_wallboxes_data) }

  before do
    config.logger = MemoryLogger.new

    # Mock the Senec cloud classes
    allow(Senec::Cloud::Connection).to receive(:new).and_return(mock_connection)
    allow(Senec::Cloud::StatsOverview).to receive(:new).and_return(mock_stats_overview)
    allow(Senec::Cloud::Wallboxes).to receive(:new).and_return(mock_wallboxes)
  end

  describe '#initialize' do
    before { adapter }

    it { expect(config.logger.info_messages).to include('Pulling from SENEC cloud every 60 seconds') }
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
        expect(solectrus_record.measure_time).to eq(1_700_000_000)
      end

      it 'has a valid inverter_power' do
        expect(solectrus_record.inverter_power).to eq(4200)
      end

      it 'has a valid house_power' do
        expect(solectrus_record.house_power).to eq(2300)
      end

      it 'has a valid grid_power_minus' do
        expect(solectrus_record.grid_power_minus).to eq(1600) # 1.6kW -> 1600W
      end

      it 'has a valid grid_power_plus' do
        expect(solectrus_record.grid_power_plus).to eq(100) # 0.1kW -> 100W
      end

      it 'has a valid bat_power_minus' do
        expect(solectrus_record.bat_power_minus).to eq(800) # 0.8kW -> 800W (discharging)
      end

      it 'has a valid bat_power_plus' do
        expect(solectrus_record.bat_power_plus).to eq(0) # 0kW -> 0W (not charging)
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
        expect(solectrus_record.current_state).to eq('LADEN')
      end

      it 'has a valid current_state_ok' do
        expect(solectrus_record.current_state_ok).to be(true)
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
          expect(solectrus_record.to_hash.keys).not_to include(:wallbox_charge_power, :house_power)
        end

        it 'contains others' do
          expect(solectrus_record.to_hash.keys).to include(:inverter_power)
        end
      end
    end

    it_behaves_like 'a SolectrusRecord'

    context 'with empty wallboxes data' do
      let(:mock_wallboxes_data) { [] }

      it 'has nil wallbox_charge_power' do
        expect(solectrus_record.wallbox_charge_power).to be_nil
      end

      it 'has nil ev_connected' do
        expect(solectrus_record.ev_connected).to be_nil
      end

      it 'calculates house_power without change' do
        expect(solectrus_record.house_power).to eq(13_300) # Full consumption without wallbox
      end
    end

    context 'with unknown state' do
      let(:mock_stats_overview_data) do
        {
          'lastupdated' => 1_700_000_000,
          'powergenerated' => { 'now' => 0.05 }, # 50W minimal PV at dawn/dusk
          'consumption' => { 'now' => 0.8 }, # 800W base load
          'gridexport' => { 'now' => 0.0 },
          'gridimport' => { 'now' => 0.75 }, # 750W grid import
          'accuimport' => { 'now' => 0.0 },
          'accuexport' => { 'now' => 0.0 },
          'acculevel' => { 'now' => 45.2 },
          'steuereinheitState' => 'UNKNOWN',
          'firmwareVersion' => 826,
        }
      end

      it 'has nil current_state' do
        expect(solectrus_record.current_state).to be_nil
      end

      it 'has nil current_state_ok' do
        expect(solectrus_record.current_state_ok).to be_nil
      end
    end

    context 'with problematic state' do
      let(:mock_stats_overview_data) do
        {
          'lastupdated' => 1_700_000_000,
          'powergenerated' => { 'now' => 1.2 }, # 1200W reduced PV
          'consumption' => { 'now' => 1.5 }, # 1500W consumption
          'gridexport' => { 'now' => 0.0 },
          'gridimport' => { 'now' => 0.8 }, # 800W grid import due to issue
          'accuimport' => { 'now' => 0.0 },
          'accuexport' => { 'now' => 0.0 }, # Battery not working
          'acculevel' => { 'now' => 25.1 }, # Low battery
          'steuereinheitState' => 'STOERUNG',
          'firmwareVersion' => 826,
        }
      end

      it 'has the state' do
        expect(solectrus_record.current_state).to eq('STOERUNG')
      end

      it 'is not ok' do
        expect(solectrus_record.current_state_ok).to be(false)
      end
    end

    it 'handles error in StatsOverview request' do
      allow(Senec::Cloud::StatsOverview).to receive(:new).and_raise(StandardError)

      expect do
        solectrus_record
      end.to change(config.logger, :error_messages).to include(/Error getting data from SENEC cloud/)
    end

    it 'handles error in Wallboxes request' do
      allow(Senec::Cloud::Wallboxes).to receive(:new).and_raise(StandardError)

      expect do
        solectrus_record
      end.to change(config.logger, :error_messages).to include(/Error getting data from SENEC cloud/)
    end
  end
end
