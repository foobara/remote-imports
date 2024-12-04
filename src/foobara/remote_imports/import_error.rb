module Foobara
  module RemoteImports
    class ImportError < Command
      include ImportBase

      depends_on ImportDomain, ImportType

      def find_manifests_to_import
        root_manifest.errors
      end

      def import_object_from_manifest
        existing_error = Foobara.foobara_root_namespace.foobara_lookup_error(
          manifest_to_import.reference,
          mode: Namespace::LookupMode::ABSOLUTE
        )

        return if existing_error

        domain_manifest = manifest_to_import.domain

        run_subcommand!(
          ImportDomain,
          raw_manifest: manifest_data,
          to_import: domain_manifest.reference,
          already_imported:
        )

        manifest_to_import.types_depended_on.each do |type|
          run_subcommand!(
            ImportType,
            raw_manifest: manifest_data,
            to_import: type.reference,
            already_imported:
          )
        end

        build_error
      end

      def build_error
        base_error_name = manifest_to_import.base_error

        base_error = if base_error_name
                       Foobara.foobara_root_namespace.foobara_lookup_error!(base_error_name)
                     else
                       # :nocov:
                       Foobara::Error
                       # :nocov:
                     end

        Foobara::Error.subclass(
          context: manifest_to_import.context_type_declaration,
          name: manifest_to_import.error_class,
          symbol: manifest_to_import.symbol.to_sym,
          base_error:,
          category: manifest_to_import.category.to_sym,
          is_fatal: manifest_to_import.is_fatal,
          abstract: manifest_to_import.abstract
        )
      end
    end
  end
end
