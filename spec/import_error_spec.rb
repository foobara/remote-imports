RSpec.describe Foobara::RemoteImports::ImportError do
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
  let(:to_import) { "SomeOrg::Math::CalculateExponent::NegativeExponentError" }
  let(:raw_manifest) { JSON.parse(manifest_json) }
  let(:manifest_json) { File.read("#{__dir__}/fixtures/foobara-manifest.json") }

  it "is creates the error" do
    expect {
      expect(outcome).to be_success
    }.to change { Object.const_defined?(:SomeOrg) }

    expect(result.size).to eq(1)
    error = result.first
    expect(error.superclass).to be(Foobara::RuntimeError)
    expect(error).to eq(SomeOrg::Math::CalculateExponent::NegativeExponentError)
    expect(SomeOrg).to be_foobara_organization
    expect(SomeOrg::Math).to be_foobara_domain
  end
end
