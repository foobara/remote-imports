RSpec.describe Foobara::RemoteImports::ImportCommand do
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
  let(:to_import) { "SomeOrg::Math::CalculateExponent" }
  let(:raw_manifest) { JSON.parse(manifest_json) }
  let(:manifest_json) { File.read("#{__dir__}/../../fixtures/foobara-manifest.json") }

  it "is creates the command" do
    expect {
      expect(outcome).to be_success
    }.to change { Object.const_defined?(:SomeOrg) }

    expect(result.size).to eq(1)
    command = result.first
    expect(command).to be < Foobara::Command
    expect(command).to eq(SomeOrg::Math::CalculateExponent)
    expect(SomeOrg).to be_foobara_organization
    expect(SomeOrg::Math).to be_foobara_domain
  end

  context "with bad manifest inputs" do
    let(:inputs) { { to_import: } }

    it "gives an error" do
      expect(outcome).to_not be_success
      expect(errors.size).to eq(1)

      error = errors.first

      expect(error).to be_a(Foobara::RemoteImports::ImportBase::BadManifestInputsError)
    end
  end

  context "with a to_import that doesn't exist" do
    let(:to_import) { "DoesNotExist" }

    it "gives an error" do
      expect(outcome).to_not be_success
      expect(errors.size).to eq(1)

      error = errors.first

      expect(error).to be_a(Foobara::RemoteImports::ImportBase::NotFoundError)
    end
  end

  context "when importing from a url" do
    let(:inputs) do
      {
        manifest_url:,
        to_import:
      }
    end
    let(:manifest_url) do
      "http://localhost:9292/manifest"
    end

    before do
      command.cast_and_validate_inputs
      FileUtils.rm_f(command.cache_file_path)
    end

    # To rerecord this, change from :none to :once and run playground-be with rackup
    it "is success", vcr: { record: :none } do
      expect(outcome).to be_success
      # make sure loading from cache works fine as well
      expect(described_class.run!(inputs.merge(cache: true))).to be_an(Array)
    end
  end

  context "with both manifest data and url" do
    let(:inputs) do
      {
        manifest_url: "http://localhost:9292/manifest",
        raw_manifest:,
        to_import:
      }
    end

    it "is not success" do
      expect(outcome).to_not be_success
      expect(errors.size).to eq(1)

      error = errors.first

      expect(error).to be_a(Foobara::RemoteImports::ImportBase::BadManifestInputsError)
    end
  end

  context "when calling the imported command", vcr: { record: :none } do
    it "can call it and get result" do
      expect {
        expect(outcome).to be_success
      }.to change { Object.const_defined?("SomeOrg::Math::CalculateExponent") }

      remote_command = SomeOrg::Math::CalculateExponent.new(base: 2, exponent: 3)
      remote_outcome = remote_command.run

      expect(remote_outcome).to be_success
      expect(remote_outcome.result).to be(8)
    end

    context "when there's an error" do
      it "can call it and get the errors", vcr: { record: :none } do
        expect {
          expect(outcome).to be_success
        }.to change { Object.const_defined?("SomeOrg::Math::CalculateExponent") }

        remote_command = SomeOrg::Math::CalculateExponent.new(base: 2, exponent: -3)
        remote_outcome = remote_command.run

        expect(remote_outcome).to_not be_success
        expect(remote_outcome.errors.size).to be(1)

        error = remote_outcome.errors.first

        expect(error).to be_a(SomeOrg::Math::CalculateExponent::NegativeExponentError)
        expect(error.symbol).to be(:negative_exponent)
        expect(error.key).to eq("runtime.negative_exponent")
        expect(error.context).to eq(exponent: -3)
        expect(error.message).to eq("Exponent cannot be negative")
        expect(error.path).to eq([])
        expect(error.runtime_path).to eq([])
      end
    end

    context "when there's an input error" do
      it "can call it and get the errors", vcr: { record: :none } do
        expect {
          expect(outcome).to be_success
        }.to change { Object.const_defined?("SomeOrg::Math::CalculateExponent") }

        remote_command = SomeOrg::Math::CalculateExponent.new(base: -2, exponent: 3)
        remote_outcome = remote_command.run

        expect(remote_outcome).to_not be_success
        expect(remote_outcome.errors.size).to be(1)

        error = remote_outcome.errors.first

        expect(error).to be_a(SomeOrg::Math::CalculateExponent::NegativeBaseError)
        expect(error.symbol).to be(:negative_base)
        expect(error.key).to eq("data.base.negative_base")
        expect(error.context).to eq(base: -2)
        expect(error.message).to eq("Base cannot be negative")
        expect(error.path).to eq([:base])
        expect(error.runtime_path).to eq([])
      end
    end
  end
end
