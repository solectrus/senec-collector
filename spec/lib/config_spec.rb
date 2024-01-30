require 'config'

describe Config do
  let(:valid_influx_options) do
    {
      influx_host: 'influx.example.com',
      influx_token: 'this.is.just.an.example',
      influx_org: 'solectrus',
      influx_bucket: 'SENEC',
    }
  end

  let(:valid_local_options) do
    valid_influx_options.merge(
      senec_host: '1.2.3.4',
    )
  end

  let(:valid_cloud_options) do
    valid_influx_options.merge(
      senec_adapter: 'cloud',
      senec_username: 'mail@example.com',
      senec_password: 'secret',
    )
  end

  describe '#initialize' do
    it 'raises an error for empty options' do
      expect { described_class.new({}) }.to raise_error(Exception)
    end

    it 'raises an error for invalid INFLUX_SCHEMA' do
      expect do
        described_class.new(valid_local_options.merge(influx_schema: 'foo'))
      end.to raise_error(Exception, /URL is invalid/)
    end

    it 'raises an error for missing INFLUX_HOST' do
      expect do
        described_class.new(valid_local_options.merge(influx_host: nil))
      end.to raise_error(Exception, /INFLUX_HOST is missing/)
    end

    it 'raises an error for missing INFLUX_ORG' do
      expect do
        described_class.new(valid_local_options.merge(influx_org: nil))
      end.to raise_error(Exception, /INFLUX_ORG is missing/)
    end

    it 'raises an error for missing INFLUX_BUCKET' do
      expect do
        described_class.new(valid_local_options.merge(influx_bucket: nil))
      end.to raise_error(Exception, /INFLUX_BUCKET is missing/)
    end

    it 'raises an error for missing INFLUX_TOKEN' do
      expect do
        described_class.new(valid_local_options.merge(influx_token: nil))
      end.to raise_error(Exception, /INFLUX_TOKEN is missing/)
    end

    context 'when local' do
      it 'initializes with valid options' do
        expect { described_class.new(valid_local_options) }.not_to raise_error
      end

      it 'raises an error for invalid SENEC_SCHEMA' do
        expect do
          described_class.new(valid_local_options.merge(senec_schema: 'httpss'))
        end.to raise_error(Exception, /URL is invalid/)
      end

      it 'limits SENEC_INTERVAL for local adapter' do
        config = described_class.new(valid_local_options.merge(senec_adapter: :local, senec_interval: 1))

        expect(config.senec_interval).to eq(5)
      end

      it 'limits SENEC_INTERVAL for cloud adapter' do
        config = described_class.new(valid_cloud_options.merge(senec_adapter: :cloud, senec_interval: 1))

        expect(config.senec_interval).to eq(30)
      end
    end

    context 'when cloud' do
      it 'raises an error for missing SENEC_USERNAME' do
        expect do
          described_class.new(valid_cloud_options.merge(senec_username: nil))
        end.to raise_error(Exception, /SENEC_USERNAME is missing/)
      end

      it 'raises an error for invalid SENEC_USERNAME' do
        expect do
          described_class.new(valid_cloud_options.merge(senec_username: 'foo'))
        end.to raise_error(Exception, /SENEC_USERNAME is invalid/)
      end

      it 'raises an error for missing SENEC_PASSWORD' do
        expect do
          described_class.new(valid_cloud_options.merge(senec_password: nil))
        end.to raise_error(Exception, /SENEC_PASSWORD is missing/)
      end
    end
  end

  describe 'senec methods' do
    context 'when local' do
      subject(:config) { described_class.new(valid_local_options) }

      it 'returns correct senec_adapter' do
        expect(config.senec_adapter).to eq(:local)
      end

      it 'returns correct senec_host' do
        expect(config.senec_host).to eq('1.2.3.4')
      end

      it 'returns default senec_schema' do
        expect(config.senec_schema).to eq(:https)
      end

      it 'returns default senec_interval' do
        expect(config.senec_interval).to eq(5)
      end

      it 'returns correct adapter' do
        expect(config.adapter).to be_a(LocalAdapter)
      end
    end

    context 'when cloud' do
      subject(:config) { described_class.new(valid_cloud_options) }

      it 'returns correct senec_adapter' do
        expect(config.senec_adapter).to eq(:cloud)
      end

      it 'returns correct adapter' do
        expect(config.adapter).to be_a(CloudAdapter)
      end

      it 'returns default senec_interval' do
        expect(config.senec_interval).to eq(60)
      end
    end
  end

  describe 'influx methods' do
    subject(:config) { described_class.new(valid_local_options) }

    it 'returns correct influx_host' do
      expect(config.influx_host).to eq('influx.example.com')
    end

    it 'returns correct influx_schema' do
      expect(config.influx_schema).to eq(:http)
    end

    it 'returns default influx_port' do
      expect(config.influx_port).to eq(8086)
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
