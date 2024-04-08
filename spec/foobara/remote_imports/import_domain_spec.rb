RSpec.describe Foobara::RemoteImports::ImportDomain do
  after do
    Object.send(:remove_const, :SomeOrg) if Object.const_defined?(:SomeOrg)
  end

  let(:command) { described_class.new(inputs) }
  let(:outcome) { command.run }
  let(:result) { outcome.result }
  let(:errors) { outcome.errors }
  let(:errors_hash) { outcome.errors_hash }

  let(:inputs) do
    {
      raw_manifest:,
      to_import:
    }
  end
  let(:to_import) { "SomeOrg::Math" }
  let(:raw_manifest) { JSON.parse(manifest_json) }
  let(:manifest_json) { File.read("#{__dir__}/../../fixtures/foobara-manifest.json") }

  it "is creates the org and domain" do
    expect {
      expect(outcome).to be_success
    }.to change { Object.const_defined?(:SomeOrg) }

    expect(result).to eq([SomeOrg::Math])
    expect(SomeOrg).to be_foobara_organization
    expect(SomeOrg::Math).to be_foobara_domain
  end
end
