require 'cloud_adapter'
require 'config'

describe CloudAdapter do
  subject(:adapter) do
    described_class.new(config:)
  end

  let(:config) { Config.from_env(senec_adapter: :cloud, senec_interval: 60, senec_system_id:) }
  let(:logger) { MemoryLogger.new }
  let(:senec_system_id) { nil }

  before do
    config.logger = logger
  end

  describe '#initialize' do
    before { adapter }

    it { expect(logger.info_messages).to include('Pulling from SENEC cloud every 60 seconds') }
  end

  describe '#connection' do
    subject { adapter.connection }

    it { is_expected.to be_a(Senec::Cloud::Connection) }
  end

  describe '#dashboard' do
    subject(:dashboard) { adapter.dashboard }

    context 'with a system id', vcr: 'senec-cloud-given-system' do
      let(:senec_system_id) { ENV.fetch('SENEC_SYSTEM_ID') }

      it { is_expected.to be_a(Senec::Cloud::Dashboard) }
    end

    context 'without a system id', vcr: 'senec-cloud-first-system' do
      let(:senec_system_id) { nil }

      it { is_expected.to be_a(Senec::Cloud::Dashboard) }
    end
  end

  describe '#solectrus_record', vcr: 'senec-cloud-first-system' do
    subject(:solectrus_record) { adapter.solectrus_record }

    it { is_expected.to be_a(SolectrusRecord) }

    it 'has an automatic id' do
      expect(solectrus_record.id).to eq(1)
    end

    it 'has a valid measure_time' do
      expect(solectrus_record.measure_time).to be > 1_700_000_000
    end

    it 'has a valid inverter_power' do
      expect(solectrus_record.inverter_power).to be > 0
    end

    it 'has a valid house_power' do
      expect(solectrus_record.house_power).to be > 0
    end

    it 'has a valid grid_power_minus' do
      expect(solectrus_record.grid_power_minus).to be > 0
    end

    it 'has a valid grid_power_plus' do
      expect(solectrus_record.grid_power_plus).to be > 0
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

    it 'handles errors' do
      allow(Senec::Cloud::Dashboard).to receive(:new).and_raise(StandardError)

      solectrus_record
      expect(logger.error_messages).to include(/Error getting data from SENEC cloud/)
    end
  end
end
