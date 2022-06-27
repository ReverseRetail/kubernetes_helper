# frozen_string_literal: true

require 'spec_helper'
RSpec.describe KubernetesHelper::Core do
  let(:settings) { { sample: { value1: 'sample value1' } } }
  let(:sample_yml) { custom_sample_yml rescue 'name: "<%= sample.value1 %>"' }
  let(:mock_file) { double('File', write: true, '<<' => true) }
  let(:inst) { described_class.new('beta') }

  before do
    allow(KubernetesHelper).to receive(:run_cmd)
    inst.config_values.merge!(settings)
    allow(File).to receive(:open).and_yield(mock_file)
    allow(File).to receive(:delete)
  end

  describe 'when parsing yml file' do
    let(:input_yml) { 'file1.yml' }
    let(:output_yml) { 'file2.yml' }
    before do
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(input_yml).and_return(sample_yml)
    end
    after { |test| inst.parse_yml_file(input_yml, output_yml) unless test.metadata[:skip_after] }

    it 'replaces config values' do
      expect(mock_file).to receive(:write).with(/#{settings[:sample][:value1]}/)
    end

    it 'parses provided yml file' do
      allow(File).to receive(:open).with(input_yml)
    end

    it 'saves parsed yml to provided path' do
      allow(File).to receive(:open).with(output_yml)
    end

    describe 'when replacing secrets as env values' do
      let(:secret_file_name) { 'secrets.yml' }
      let(:secret_name) { 'secret_name' }
      let(:custom_sample_yml) do
        %{
spec:
    template:
      spec:
        containers:
          - import_secrets: ['#{secret_file_name}', '#{secret_name}']
          - static_env: true
        }
      end
      before { allow(File).to receive(:read).with(/#{secret_file_name}$/).and_call_original }

      it 'loads secrets from provided yml file' do
        expect(File).to receive(:read).with(/#{secret_file_name}$/)
      end

      it 'replaces secrets' do
        expect(mock_file).to receive(:write).with(/name: #{secret_name}/)
      end

      describe 'when including defined env vars' do
        it 'includes static env vars' do
          inst.config_values[:deployment][:env_vars] = { ENV: 'production' }
          allow(mock_file).to receive(:write) do |content|
            expect(content).to include('name: ENV')
            expect(content).to include('value: production')
          end
        end

        it 'parses a complex external secret' do
          secrets = { PAPERTRAIL_PORT: { name: 'common_secrets', key: 'paper_trail_port' } }
          inst.config_values[:deployment][:env_vars] = secrets
          allow(mock_file).to receive(:write) do |content|
            expect(content).to include('name: PAPERTRAIL_PORT')
            expect(content).to include('name: common_secrets')
            expect(content).to include('key: paper_trail_port')
          end
        end
      end
    end

    describe 'when including multiple job pods' do
      it 'includes pod settings for all job pods', skip_after: true do
        settings = inst.config_values
        job_pods = [{ name: 'pod1', command: 'cmd 1' }, { name: 'pod2', command: 'cmd 2' }]
        settings[:deployment][:job_apps] = job_pods
        job_pods.each do |pod|
          allow(mock_file).to receive(:write).with(include("name: #{pod[:name]}"))
          allow(mock_file).to receive(:write).with(include(pod[:command]))
        end
        inst.parse_yml_file('lib/templates/deployment.yml', output_yml)
      end
    end

    describe 'when yml includes multiple documents' do
      let(:sample_yml) { "documents:\n    - name: 'Document 1'\n    - name: 'Document 2'" }

      it 'support for multiple documents to share yml variables' do
        expect(mock_file).to receive(:write).twice
      end
    end
  end

  describe 'when running command' do
    it 'replaces config value' do
      expect(KubernetesHelper).to receive(:run_cmd).with('echo sample value1')
      inst.run_command('echo <%= sample.value1 %>')
    end
  end

  describe 'when executing bash file' do
    it 'replaces config value' do
      script_path = KubernetesHelper.settings_path('cd.sh')
      allow(File).to receive(:read).with(script_path).and_return('echo <%= sample.value1 %>')
      expect(File).to receive(:write).with(/tmp_script.sh$/, 'echo sample value1')
      inst.run_script(script_path)
    end
  end
end
