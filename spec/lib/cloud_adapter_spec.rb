require 'cloud_adapter'
require 'config'

describe CloudAdapter do
  subject(:adapter) do
    described_class.new(config:)
  end

  let(:config) { Config.from_env(senec_adapter: :cloud, senec_interval: 60, senec_system_id:, senec_token:) }
  let(:senec_system_id) { nil }
  let(:senec_token) { nil }

  before do
    config.logger = MemoryLogger.new
  end

  describe '#initialize' do
    before { adapter }

    it { expect(config.logger.info_messages).to include('Pulling from SENEC cloud every 60 seconds') }
  end

  describe '#connection' do
    subject { adapter.connection }

    it { is_expected.to be_a(Senec::Cloud::Connection) }
  end

  describe '#solectrus_record' do
    subject(:solectrus_record) { adapter.solectrus_record }

    shared_examples 'a SolectrusRecord' do
      it { is_expected.to be_a(SolectrusRecord) }

      it 'has an automatic id' do
        expect(solectrus_record.id).to eq(1)
      end

      it 'has a valid measure_time' do
        expect(solectrus_record.measure_time).to be > 1_700_000_000
      end

      it 'has a valid inverter_power' do
        expect(solectrus_record.inverter_power).to be >= 0
      end

      it 'has a valid house_power' do
        expect(solectrus_record.house_power).to be >= 0
      end

      it 'has a valid grid_power_minus' do
        expect(solectrus_record.grid_power_minus).to be >= 0
      end

      it 'has a valid grid_power_plus' do
        expect(solectrus_record.grid_power_plus).to be >= 0
      end

      it 'has a valid bat_power_minus' do
        expect(solectrus_record.bat_power_minus).to be >= 0
      end

      it 'has a valid bat_power_plus' do
        expect(solectrus_record.bat_power_plus).to be >= 0
      end

      it 'has a valid bat_fuel_charge' do
        expect(solectrus_record.bat_fuel_charge).to be >= 0
      end

      it 'has a valid bat_charge_current' do
        expect(solectrus_record.bat_charge_current).to be_a(Float)
      end

      it 'has a valid bat_voltage' do
        expect(solectrus_record.bat_voltage).to be_a(Float)
      end

      it 'has a valid case_temp' do
        expect(solectrus_record.case_temp).to be > 20
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

    shared_examples 'a SolectrusRecord for V3' do
      it 'has a valid current_state' do
        expect(solectrus_record.current_state).to be_a(String)
      end

      it 'has a valid current_state_ok' do
        expect(solectrus_record.current_state_ok).to be(true)
      end

      it 'has a valid application_version' do
        expect(solectrus_record.application_version.to_i).to be >= 826
      end
    end

    shared_examples 'a SolectrusRecord for V4' do
      it 'has no current_state' do
        expect(solectrus_record.current_state).to be_nil
      end

      it 'has no current_state_ok' do
        expect(solectrus_record.current_state_ok).to be_nil
      end

      it 'has no application_version' do
        expect(solectrus_record.application_version).to be_nil
      end
    end

    context 'when SENEC.Home V3' do
      context 'with a system id', vcr: 'senec-cloud-given-system' do
        let(:senec_system_id) { ENV.fetch('SENEC_SYSTEM_ID') }

        it_behaves_like 'a SolectrusRecord'
        it_behaves_like 'a SolectrusRecord for V3'
      end

      context 'with token', vcr: 'senec-cloud-with-token' do
        let(:senec_system_id) { nil }
        let(:senec_token) { ENV.fetch('SENEC_TOKEN') }

        it_behaves_like 'a SolectrusRecord'
        it_behaves_like 'a SolectrusRecord for V3'
      end

      context 'without a system id', vcr: 'senec-cloud-first-system' do
        let(:senec_system_id) { nil }

        it_behaves_like 'a SolectrusRecord'
        it_behaves_like 'a SolectrusRecord for V3'
      end
    end

    context 'when SENEC.Home 4' do
      context 'with a system id' do
        let(:senec_system_id) { ENV.fetch('SENEC_SYSTEM_ID') }

        let(:technical_data) do
          {
            casing: {
              temperatureInCelsius: 28.0,
            },
            mcu: {
              mainControllerState: { name: 'UNKNOWN', severity: 'WARNING' },
            },
            batteryPack: {
              currentVoltageInV: 193.0,
              currentCurrentInA: 0.0299,
            },
          }
        end

        let(:dashboard_data) do
          {
            aktuell: {
              stromerzeugung: { wert: 0.01, einheit: 'W' },
              stromverbrauch: { wert: 0.0, einheit: 'W' },
              netzeinspeisung: { wert: 0.01, einheit: 'W' },
              netzbezug: { wert: 0.01, einheit: 'W' },
              speicherbeladung: { wert: 0.01, einheit: 'W' },
              speicherentnahme: { wert: 0.01, einheit: 'W' },
              speicherfuellstand: { wert: 1.0E-5, einheit: '%' },
              autarkie: { wert: 1.0E-5, einheit: '%' },
              wallbox: { wert: 0.01, einheit: 'W' },
            },
            zeitstempel: '2023-12-08T11:04:18Z',
            electricVehicleConnected: false,
          }
        end

        before do
          stub_request(:post, 'https://app-gateway.prod.senec.dev/v1/senec/login')
          stub_request(:get, "https://app-gateway.prod.senec.dev/v1/senec/systems/#{senec_system_id}/dashboard").to_return(
            headers: { content_type: 'application/json' }, body: dashboard_data.to_json,
          )
          stub_request(:get, "https://app-gateway.prod.senec.dev/v1/senec/systems/#{senec_system_id}/technical-data")
            .to_return(status: 200, headers: { content_type: 'application/json' }, body: technical_data.to_json)
        end

        it_behaves_like 'a SolectrusRecord'
        it_behaves_like 'a SolectrusRecord for V4'
      end
    end

    it 'handles error in Dashboard request' do
      allow(Senec::Cloud::Dashboard).to receive(:new).and_raise(StandardError)

      expect do
        solectrus_record
      end.to change(config.logger, :error_messages).to include(/Error getting data from SENEC cloud/)
    end

    it 'handles error in TechnicalData request' do
      allow(Senec::Cloud::TechnicalData).to receive(:new).and_raise(StandardError)

      expect do
        solectrus_record
      end.to change(config.logger, :error_messages).to include(/Error getting data from SENEC cloud/)
    end
  end
end
