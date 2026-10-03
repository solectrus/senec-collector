require 'senec_pull'
require 'config'

describe SenecPull do
  let(:queue) { Queue.new }
  let(:config) { Config.from_env(senec_adapter: :local, senec_interval: 5) }
  let(:senec_pull) do
    described_class.new(config:, queue:)
  end

  let(:logger) { MemoryLogger.new }

  before do
    config.logger = logger
  end

  describe '#next', vcr: 'senec-local' do
    context 'when successful' do
      it 'increments the queue length' do
        senec_pull.next

        expect(queue.length).to eq(1)
      end
    end

    context 'when SENEC returns no record' do
      it 'does not increment the queue length' do
        allow(config.adapter).to receive(:solectrus_record).and_return(nil)

        senec_pull.next

        expect(queue.length).to eq(0)
      end
    end

    context 'when the buffer is full' do
      before { stub_const('SenecPull::MAX_QUEUE_SIZE', 2) }

      it 'drops the oldest record' do
        3.times { senec_pull.next }

        expect(queue.length).to eq(2)
        expect(queue.pop.id).to eq(2)
      end

      it 'logs only once' do
        4.times { senec_pull.next }

        expect(logger.error_messages.grep(/Buffer is full/).size).to eq(1)
      end
    end

    context 'when it fails' do
      it 'raises Senec::Local::Error and does not increment queue length' do
        allow(queue).to receive(:<<).and_raise(Senec::Local::Error)

        expect { senec_pull.next }.to raise_error(Senec::Local::Error)
        expect(queue.length).to eq(0)
      end
    end
  end
end
