require 'influx_push'
require 'senec_pull'
require 'config'

describe InfluxPush do
  let(:config) { Config.from_env(senec_adapter: :local, senec_interval: 5) }
  let(:queue) { Queue.new }
  let!(:senec_pull) do
    SenecPull.new(config:, queue:)
  end
  let(:logger) { MemoryLogger.new }

  before do
    config.logger = logger
  end

  describe '#run', vcr: 'senec-local' do
    context 'with a single record' do
      before { fill_queue }

      it 'successfully pushes a record to InfluxDB' do
        assert_success(1) do
          run_influx_push
        end
      end
    end

    context 'with multiple records' do
      before { fill_queue(3) }

      it 'successfully pushes multiple records to InfluxDB' do
        assert_success(3) do
          run_influx_push
        end
      end
    end

    context 'when failure' do
      before do
        fill_queue

        allow(FluxWriter).to receive(:new).and_return(FailingFluxWriter.new)
      end

      it 'handles failure during record push' do
        assert_failure(1) do
          run_influx_push
        end
      end
    end
  end

  # Helper methods

  def fill_queue(num_records = 1)
    num_records.times { senec_pull.next }

    expect(queue.length).to eq(num_records)
  end

  def run_influx_push
    thread = Thread.new do
      VCR.use_cassette('influx-success') do
        pusher = described_class.new(config:, queue:)
        pusher.run
      end
    end

    Timeout.timeout(1) { loop until queue.empty? }
    queue.close
    thread.join
  end

  def assert_success(num_records)
    yield

    (1..num_records).each do |i|
      expect(logger.info_messages).to include "Successfully pushed record ##{i} to InfluxDB"
    end

    expect(queue.length).to eq(0)
  end

  def assert_failure(num_records, &)
    expect(&).to raise_error(Timeout::Error)
    expect(logger.error_messages).to include(/Error while pushing record #1 to InfluxDB/)
    expect(queue.length).to eq(num_records)
  end
end

class FailingFluxWriter
  def push(_record)
    raise InfluxDB2::InfluxError.new(message: nil, code: nil, reference: nil, retry_after: nil)
  end
end
