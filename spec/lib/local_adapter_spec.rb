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

    it { expect(logger.info_messages).to include('Pulling from your local SENEC at https://senec.fritz.box every 5 seconds') }
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

    context 'when retrying' do
      before do
        stub_const('LocalAdapter::MAX_RETRIES', 5)
        allow(adapter).to receive(:sleep) # rubocop:disable RSpec/SubjectStub
      end

      it 'retries on failure until it succeeds' do
        state_instance = instance_double(Senec::Local::State)
        allow(Senec::Local::State).to receive(:new).and_return(state_instance)
        call_count = 0
        allow(state_instance).to receive(:names) do
          call_count += 1
          raise StandardError, 'boom' if call_count == 1

          { 0 => 'OK', 1 => 'CHARGE' }
        end

        expect(state_names).to eq({ 0 => 'OK', 1 => 'CHARGE' })
        expect(logger.error_messages).to include(/Failed \(attempt 1\): boom\. Retrying in 1s/)
      end

      it 'falls back to numeric codes when names returns nil (regex did not match)' do
        state_instance = instance_double(Senec::Local::State)
        allow(Senec::Local::State).to receive(:new).and_return(state_instance)
        allow(state_instance).to receive(:names).and_return(nil)

        (0..98).each { |i| expect(state_names[i]).to eq(i.to_s) }
        expect(logger.error_messages).to include(/No state names found in source code/)
      end

      it 'falls back to numeric codes when names returns an empty hash' do
        state_instance = instance_double(Senec::Local::State)
        allow(Senec::Local::State).to receive(:new).and_return(state_instance)
        allow(state_instance).to receive(:names).and_return({})

        (0..98).each { |i| expect(state_names[i]).to eq(i.to_s) }
        expect(logger.error_messages).to include(/No state names found in source code/)
      end

      it 'gives up after MAX_RETRIES and re-raises' do
        stub_const('LocalAdapter::MAX_RETRIES', 2)
        allow(Senec::Local::State).to receive(:new).and_raise(StandardError, 'boom')

        expect { state_names }.to raise_error(StandardError, 'boom')
      end
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
