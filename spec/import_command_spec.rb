RSpec.describe Foobara::RemoteImports::ImportCommand do
  after do
    Foobara.reset_alls

    [
      :SomeOrg,
      :SomeOtherOrg,
      :FoobaraAi,
      :GlobalCommand,
      :NestedModels2,
      :NestedModels3,
      :NestedModels,
      :NestedModelsNoCollisions,
      :SomeDomainWithoutOrg,
      :ComputeExponent
    ].each do |to_remove|
      Object.send(:remove_const, to_remove) if Object.const_defined?(to_remove)
    end

    [
      :Ai
    ].each do |to_remove|
      Foobara.send(:remove_const, to_remove) if Foobara.const_defined?(to_remove)
    end
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
  let(:manifest_json) { File.read("#{__dir__}/fixtures/foobara-manifest.json") }

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

  context "when using a partial match" do
    let(:to_import) { "CreateNestedNoCollisions" }

    it "creates the command" do
      expect(outcome).to be_success

      expect(result.size).to eq(1)
      command = result.first
      expect(command).to be < Foobara::Command
      expect(command).to eq(NestedModelsNoCollisions::CreateNestedNoCollisions)
    end
  end

  context "when creating all commands" do
    let(:inputs) do
      {
        raw_manifest:
      }
    end

    it "imports them all" do
      expect(outcome).to be_success

      r = outcome.result

      expect(r).to_not be_empty
      expect(r).to all be < Foobara::Command
    end
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

    context "when using a different base command class" do
      let(:base_command_class) do
        stub_class "RemoteCommandWithHeader", Foobara::RemoteCommand do
          def build_request_headers
            super["Another-Header"] = "foobarbaz"
          end
        end
      end
      let(:inputs) do
        super().merge(base_command_class:)
      end

      it "uses is an instance of and has behavior from the base class", vcr: { record: :none } do
        expect {
          expect(outcome).to be_success
        }.to change { Object.const_defined?("SomeOrg::Math::CalculateExponent") }

        expect(SomeOrg::Math::CalculateExponent.superclass).to be RemoteCommandWithHeader

        remote_command = SomeOrg::Math::CalculateExponent.new(base: 2, exponent: 3)
        remote_outcome = remote_command.run

        expect(remote_outcome).to be_success
        expect(remote_outcome.result).to be(8)

        expect(remote_command.request_headers["Another-Header"]).to eq("foobarbaz")

        # NOTE: bad form to couple to an instance variable so delete this assertion if need be
        interaction = VCR.current_cassette.http_interactions.instance_variable_get(:@used_interactions).first
        expect(interaction.request.headers["Another-Header"]).to eq(["foobarbaz"])
      end
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

  context "when the manifest has requires_authentication commands" do
    let(:manifest_json) { File.read("#{__dir__}/fixtures/manifest-with-auth.json") }
    let(:to_import) { "ComputeExponent" }
    let(:inputs) do
      {
        raw_manifest:,
        to_import:,
        auth_header: ["x-api-key", -> { "foobarbaz" }]
      }
    end

    # This was recorded while the demo blog-rails app was around.
    # Not sure if it still is or if it still has ComputeExponent.
    # If not and you need to rerecord this, then you'll have to find another manifest/command. Sorry :(
    context "when calling the imported command", vcr: { record: :none } do
      it "sets an auth header" do
        expect(outcome).to be_success

        expect(ComputeExponent.superclass).to be(Foobara::AuthenticatedRemoteCommand)

        remote_command = ComputeExponent.new(base: 2, exponent: 3)
        remote_outcome = remote_command.run

        expect(remote_outcome).to_not be_success
        expect(remote_outcome.errors.size).to be(1)
        expect(remote_outcome.errors_hash.keys).to eq(["runtime.unauthenticated"])

        expect(remote_command.request_headers["x-api-key"]).to eq("foobarbaz")
      end

      context "when the header block takes the command" do
        let(:inputs) do
          super().merge(auth_header: ["x-api-key", ->(command) { command.class.name }])
        end

        it "sets an auth header" do
          expect(outcome).to be_success

          remote_command = ComputeExponent.new(base: 2, exponent: 3)
          remote_outcome = remote_command.run

          expect(remote_outcome.errors_hash.keys).to eq(["runtime.unauthenticated"])
          expect(remote_command.request_headers["x-api-key"]).to eq("ComputeExponent")
        end
      end
    end

    context "when the manifest itself requires auth" do
      let(:inputs) do
        super().merge(manifest_requires_auth: true)
      end

      describe "#load_manifest_headers" do
        it "contains the API key" do
          command.cast_and_validate_inputs

          expect(command.load_manifest_headers["x-api-key"]).to eq("foobarbaz")
        end

        context "when api key is a proc" do
          let(:inputs) do
            super().merge(auth_header: ["x-api-key", proc { "foobarbaz" }])
          end

          it "contains the API key" do
            command.cast_and_validate_inputs

            expect(command.load_manifest_headers["x-api-key"]).to eq("foobarbaz")
          end
        end
      end
    end
  end
end
