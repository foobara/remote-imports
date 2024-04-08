RSpec.describe Foobara::RemoteImports::ImportOrganization do
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
  let(:to_import) { "SomeOrg" }
  let(:raw_manifest) { JSON.parse(manifest_json) }
  let(:manifest_json) { File.read("#{__dir__}/../../fixtures/foobara-manifest.json") }

  it "is successful" do
    expect(outcome).to be_success
    expect(result).to eq([SomeOrg])
    expect(SomeOrg.foobara_organization?).to be true
  end
end
