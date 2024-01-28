require 'loop'
require 'config'

describe Loop do
  let(:config) { Config.from_env }

  describe '#start' do
    it 'outputs the correct information when started' do
      expect do
        VCR.use_cassette('senec_state_names') do
          VCR.use_cassette('senec_success') do
            VCR.use_cassette('influx_success') do
              described_class.start(config:, max_count: 1)
            end
          end
        end
      end.to output(/Got record #1/).to_stdout
    end
  end
end
