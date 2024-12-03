RSpec.describe Foobara::RemoteImports::ImportCommand do
  after do
    Foobara.reset_alls

    %i[
      Capybara
      CreateCapybara
      FindCapybara
      IncrementAge
    ].each do |to_remove|
      Object.send(:remove_const, to_remove) if Object.const_defined?(to_remove)
    end
  end

  let(:command) { described_class.new(inputs) }
  let(:outcome) { command.run }
  let(:result) { outcome.result }
  let(:errors) { outcome.errors }
  let(:errors_hash) { outcome.errors_hash }

  let(:inputs) do
    {
      raw_manifest:
    }
  end
  let(:raw_manifest) { JSON.parse(manifest_json) }
  let(:manifest_json) { File.read("#{__dir__}/../../fixtures/another-manifest.json") }

  it "is creates the command and converts entities to models" do
    expect {
      expect(outcome).to be_success
    }.to change { Object.const_defined?(:Capybara) }

    expect(Capybara).to be < Foobara::Model
    expect(Capybara).to_not be < Foobara::Entity
  end
end
