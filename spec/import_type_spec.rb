RSpec.describe Foobara::RemoteImports::ImportType do
  after do
    Foobara.reset_alls
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
  let(:to_import) { "SomeOrg::Auth::User" }
  let(:raw_manifest) { JSON.parse(manifest_json) }
  let(:manifest_json) { File.read("#{__dir__}/fixtures/foobara-manifest.json") }

  it "is creates the type, org, and domain" do
    expect {
      expect(outcome).to be_success
    }.to change { Object.const_defined?(:SomeOrg) }

    expect(result.size).to eq(1)
    type = result.first
    expect(type).to be_a(Foobara::Types::Type)
    expect(type).to eq(SomeOrg::Auth::User.model_type)
    expect(SomeOrg::Auth::User.model_type.declaration_data[:type]).to eq(:detached_entity)
    expect(SomeOrg::Auth::User.superclass).to be(Foobara::DetachedEntity)
    expect(SomeOrg).to be_foobara_organization
    expect(SomeOrg::Auth).to be_foobara_domain
  end
end
