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

  describe '#initialize' do
    before { adapter }

    it { expect(logger.info_messages).to include('Pulling from your local SENEC at https://192.168.178.29 every 5 seconds') }
  end

  describe '#connection' do
    subject { adapter.connection }

    it { is_expected.to be_a(Senec::Local::Connection) }
  end

  describe '#state_names', vcr: 'senec-local' do
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

    it 'handles errors' do
      allow(Senec::Local::State).to receive(:new).and_raise(StandardError)

      (0..98).each { |i| expect(state_names[i]).to eq(i.to_s) }
      expect(logger.error_messages).to include(/Failed: StandardError/)
    end
  end

  describe '#solectrus_record', vcr: 'senec-local' do
    subject(:solectrus_record) { adapter.solectrus_record }

    it { is_expected.to be_a(SolectrusRecord) }

    it 'has an automatic id' do
      expect(solectrus_record.id).to eq(1)
    end

    it 'has a valid measure_time' do
      expect(solectrus_record.measure_time).to be > 1_700_000_000
    end

    it 'has a valid current_state' do
      expect(solectrus_record.current_state).to be_a(String)
    end

    it 'handles errors' do
      allow(Senec::Local::Request).to receive(:new).and_raise(StandardError)

      solectrus_record
      expect(logger.error_messages).to include(/Error getting data from SENEC at/)
    end

    context 'with senec_ignore' do
      let(:config) do
        Config.from_env(
          senec_adapter: :local,
          senec_ignore: 'wallbox_charge_power,house_power',
        )
      end

      it 'removes keys for ignored fields' do
        expect(solectrus_record.to_hash.keys).not_to include(:wallbox_charge_power, :house_power)
      end

      it 'contains others' do
        expect(solectrus_record.to_hash.keys).to include(:inverter_power, :measure_time, :current_state)
      end
    end
  end
end
