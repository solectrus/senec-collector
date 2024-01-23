require 'config'

describe Config do
  let(:valid_options) do
    {
      senec_host: '1.2.3.4',
      senec_schema: 'http',
      senec_interval: 5,
      influx_host: 'influx.example.com',
      influx_schema: 'https',
      influx_port: '443',
      influx_token: 'this.is.just.an.example',
      influx_org: 'solectrus',
      influx_bucket: 'SENEC',
      influx_measurement: 'SENEC',
    }
  end

  describe '#initialize' do
    it 'initializes with valid options' do
      expect { described_class.new(valid_options) }.not_to raise_error
    end

    context 'with invalid options' do
      it 'raises an error for empty options' do
        expect { described_class.new({}) }.to raise_error(Exception)
      end

      it 'raises an error for invalid senec_interval' do
        expect do
          described_class.new(valid_options.merge(senec_interval: 0))
        end.to raise_error(Exception, /Interval is invalid/)
      end

      it 'raises an error for invalid influx_schema' do
        expect do
          described_class.new(valid_options.merge(influx_schema: 'foo'))
        end.to raise_error(Exception, /URL is invalid/)
      end
    end
  end

  describe 'senec methods' do
    subject(:config) { described_class.new(valid_options) }

    it 'returns correct senec_host' do
      expect(config.senec_host).to eq('1.2.3.4')
    end

    it 'returns correct senec_schema' do
      expect(config.senec_schema).to eq('http')
    end

    it 'returns correct senec_interval' do
      expect(config.senec_interval).to eq(5)
    end
  end

  describe 'influx methods' do
    subject(:config) { described_class.new(valid_options) }

    it 'returns correct influx_host' do
      expect(config.influx_host).to eq('influx.example.com')
    end

    it 'returns correct influx_schema' do
      expect(config.influx_schema).to eq('https')
    end

    it 'returns correct influx_port' do
      expect(config.influx_port).to eq('443')
    end

    it 'returns correct influx_token' do
      expect(config.influx_token).to eq('this.is.just.an.example')
    end

    it 'returns correct influx_org' do
      expect(config.influx_org).to eq('solectrus')
    end

    it 'returns correct influx_bucket' do
      expect(config.influx_bucket).to eq('SENEC')
    end

    it 'returns correct influx_measurement' do
      expect(config.influx_measurement).to eq('SENEC')
    end
  end
end
