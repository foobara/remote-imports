require_relative "import_domain"
require_relative "import_type"
require_relative "import_error"
require_relative "../remote_command"

module Foobara
  module RemoteImports
    class ImportCommand < Command
      include ImportBase

      depends_on ImportDomain, ImportType, ImportError

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

        Util.make_class_p(manifest_to_import.reference, RemoteCommand)

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
        url_base = root_manifest.metadata["url"].gsub(/\/manifest$/, "")

        RemoteCommand.subclass(
          url_base:,
          description: manifest_to_import.description,
          inputs: manifest_to_import.inputs_type.relevant_manifest,
          result: manifest_to_import.result_type.relevant_manifest,
          possible_errors: manifest_to_import.possible_errors,
          name: manifest_to_import.reference
        )
      end
    end
  end
end
