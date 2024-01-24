require 'local_adapter'
require 'config'

describe LocalAdapter do
  subject(:adapter) do
    described_class.new(config:)
  end

  let(:config) { Config.from_env(senec_adapter: :local, senec_interval: 5) }
  let(:logger) { MemoryLogger.new }

  before do
    config.logger = logger
  end

  around do |example|
    VCR.use_cassette('senec_success') do
      example.run
    end
  end

  describe '#init_message' do
    subject { adapter.init_message }

    it { is_expected.to eq('Pulling from your local SENEC at https://192.168.178.29 every 5 seconds') }
  end

  describe '#connection' do
    subject { adapter.connection }

    it { is_expected.to be_a(Senec::Local::Connection) }
  end

  describe '#state_names' do
    subject(:state_names) { adapter.state_names }

    it { is_expected.to be_a(Hash) }

    it 'has keys from 0..98' do
      expect(state_names.keys.sort).to eq((0..98).to_a)
    end

    it 'writes messages' do
      state_names

      expect(logger.info_messages).to include('Getting state names (language: de) from SENEC by parsing source code...')
      expect(logger.info_messages).to include('OK, got 99 state names')
    end
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

    it 'handles errors' do
      allow(Senec::Local::Request).to receive(:new).and_raise(StandardError)

      solectrus_record
      expect(logger.error_messages).to include(/Error getting data from SENEC at/)
    end
  end
end
