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
        assert_success('record #1') do
          run_influx_push
        end
      end
    end

    context 'with multiple records' do
      before { fill_queue(3) }

      it 'successfully pushes multiple records to InfluxDB in one batch' do
        assert_success('3 records') do
          run_influx_push
        end
      end
    end

    context 'with more records than the batch size' do
      before do
        stub_const('InfluxPush::BATCH_SIZE', 2)
        fill_queue(3)
      end

      it 'successfully pushes records in multiple batches' do
        assert_success('2 records', 'record #3') do
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

    context 'when InfluxDB rejects a record' do
      before do
        fill_queue(3)

        allow(FluxWriter).to receive(:new).and_return(RejectingFluxWriter.new(rejected_id: 2))
      end

      it 'drops the rejected record and pushes the others' do
        assert_success('record #1', 'record #3') do
          run_influx_push
        end

        expect(logger.error_messages).to include(/InfluxDB rejected record #2, dropping it/)
        expect(logger.info_messages).not_to include(/Successfully pushed record #2/)
      end
    end

    context 'when InfluxDB recovers' do
      before do
        fill_queue(2)

        allow(FluxWriter).to receive(:new).and_return(RecoveringFluxWriter.new)
      end

      it 'pushes buffered records and logs the failure only once' do
        pusher = described_class.new(config:, queue:)
        allow(pusher).to receive(:sleep)

        thread = Thread.new { pusher.run }
        Timeout.timeout(1) { sleep 0.01 until logger.info_messages.grep(/Successfully pushed/).any? }
        queue.close
        thread.join

        expect(logger.info_messages).to include('Successfully pushed 2 records to InfluxDB')
        expect(logger.error_messages.grep(/Error while pushing/).size).to eq(1)
        expect(logger.info_messages).to include(/InfluxDB is available again/)
      end

      it 'does not log the failure if InfluxDB is already known to be unavailable' do
        pusher = described_class.new(config:, queue:)
        allow(pusher).to receive(:sleep)
        pusher.mark_unavailable

        thread = Thread.new { pusher.run }
        Timeout.timeout(1) { sleep 0.01 until logger.info_messages.grep(/Successfully pushed/).any? }
        queue.close
        thread.join

        expect(logger.error_messages).to be_empty
        expect(logger.info_messages).to include(/InfluxDB is available again/)
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

  def assert_success(*descriptions)
    yield

    descriptions.each do |description|
      expect(logger.info_messages).to include "Successfully pushed #{description} to InfluxDB"
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
  def push(_records)
    raise InfluxDB2::InfluxError.new(message: nil, code: nil, reference: nil, retry_after: nil)
  end
end

class RecoveringFluxWriter
  def initialize
    @failures = 2
  end

  def push(_records)
    return if (@failures -= 1).negative?

    raise InfluxDB2::InfluxError.new(message: nil, code: nil, reference: nil, retry_after: nil)
  end
end

class RejectingFluxWriter
  def initialize(rejected_id:)
    @rejected_id = rejected_id
  end

  def push(records)
    return if records.none? { |record| record.id == @rejected_id }

    raise InfluxDB2::InfluxError.new(message: 'field type conflict', code: '422', reference: nil, retry_after: nil)
  end
end
