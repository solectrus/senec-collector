require 'cloud_adapter'
require 'config'

describe CloudAdapter do
  subject(:adapter) do
    described_class.new(config:)
  end

  let(:config) { Config.from_env(senec_adapter: :cloud, senec_interval: 60) }
  let(:logger) { MemoryLogger.new }

  before do
    config.logger = logger
  end

  around do |example|
    VCR.use_cassette('senec_cloud') do
      example.run
    end
  end

  describe '#init_message' do
    subject { adapter.init_message }

    it { is_expected.to eq('Pulling from SENEC cloud every 60 seconds') }
  end

  describe '#connection' do
    subject { adapter.connection }

    it { is_expected.to be_a(Senec::Cloud::Connection) }
  end

  describe '#solectrus_record' do
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
