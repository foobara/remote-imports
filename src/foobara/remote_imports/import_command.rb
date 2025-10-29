require_relative "import_domain"
require_relative "import_type"
require_relative "import_error"
require_relative "../remote_command"

module Foobara
  module RemoteImports
    class ImportCommand < Command
      include ImportBase

      add_inputs do
        base_command_class :duck, :allow_nil
        auth_header :tuple,
                    element_type_declarations: [:string, :duck],
                    description: "A header name, header value/proc pair."
        manifest_requires_auth :boolean, default: false
      end

      depends_on ImportDomain, ImportType, ImportError

      def load_manifest_headers
        if manifest_requires_auth
          key = auth_header.first
          value = auth_header.last

          if value.is_a?(Proc)
            value = if value.lambda? && value.arity == 0
                      value.call
                    else
                      value.call(self)
                    end
          end

          super.merge(key => value)
        else
          super
        end
      end

      def find_manifests_to_import
        root_manifest.commands
      end

      def import_object_from_manifest
        existing_command = Foobara.foobara_root_namespace.foobara_lookup_command(
          manifest_to_import.reference,
          mode: Namespace::LookupMode::ABSOLUTE
        )

        return if existing_command

        domain_manifest = manifest_to_import.domain

        run_subcommand!(
          ImportDomain,
          raw_manifest: manifest_data,
          to_import: domain_manifest.reference,
          already_imported:
        )

        Util.make_class_p(manifest_to_import.reference, determine_base_command_class)

        manifest_to_import.types_depended_on.each do |type|
          run_subcommand!(
            ImportType,
            raw_manifest: manifest_data,
            to_import: type.reference,
            already_imported:
          )
        end

        build_errors
        build_command
      end

      def build_errors
        manifest_to_import.possible_errors.each_value do |possible_error|
          error = possible_error.error

          existing_error = Foobara.foobara_root_namespace.foobara_lookup_error(
            error.reference,
            mode: Namespace::LookupMode::ABSOLUTE
          )

          next if existing_error

          run_subcommand!(
            ImportError,
            raw_manifest: manifest_data,
            to_import: error.reference,
            already_imported:
          )
        end
      end

      def build_command
        url_base = root_manifest.metadata["url"]
        url_base = URI.parse(url_base)
        url_base = URI::Generic.new(url_base.scheme, url_base.userinfo, url_base.host, url_base.port,
                                    nil, nil, nil, nil, nil)
        url_base = url_base.to_s

        domain = Namespace.global.foobara_lookup_domain!(
          manifest_to_import.domain.scoped_full_path,
          mode: Namespace::LookupMode::ABSOLUTE_SINGLE_NAMESPACE
        )

        inputs_type = nil
        result_type = nil

        TypeDeclarations.strict_stringified do
          inputs_type = domain.foobara_type_from_declaration(manifest_to_import.inputs_type.relevant_manifest)
          result_type = domain.foobara_type_from_declaration(manifest_to_import.result_type.relevant_manifest)
        end

        subclass_args = {
          url_base:,
          description: manifest_to_import.description,
          inputs: inputs_type,
          result: result_type,
          possible_errors: manifest_to_import.possible_errors,
          name: manifest_to_import.reference,
          base: determine_base_command_class
        }

        if determine_base_command_class == AuthenticatedRemoteCommand
          subclass_args.merge!(auth_header:)
        end

        determine_base_command_class.subclass(**subclass_args)
      end

      def determine_base_command_class
        @determine_base_command_class ||= if base_command_class
                                            base_command_class
                                          elsif manifest_to_import.requires_authentication? &&
                                                auth_header
                                            AuthenticatedRemoteCommand
                                          else
                                            RemoteCommand
                                          end
      end
    end
  end
end
