module Foobara
  module RemoteImports
    class ImportType < Command
      include ImportBase

      depends_on ImportDomain, ImportType

      def find_manifests_to_import
        root_manifest.types
      end

      def import_object_from_manifest
        existing_type = Foobara.foobara_root_namespace.foobara_lookup_type(
          manifest_to_import.reference,
          mode: Namespace::LookupMode::ABSOLUTE
        )

        return if existing_type

        manifest_to_import.types_depended_on.each do |depended_on_type|
          run_subcommand!(
            ImportType,
            raw_manifest: manifest_data,
            to_import: depended_on_type.reference,
            already_imported:
          )
        end

        domain_manifest = manifest_to_import.domain

        run_subcommand!(
          ImportDomain,
          raw_manifest: manifest_data,
          to_import: domain_manifest.reference,
          already_imported:
        )

        domain = Foobara.foobara_root_namespace.foobara_lookup_domain!(
          manifest_to_import.domain.reference,
          mode: Namespace::LookupMode::ABSOLUTE
        )

        domain.foobara_register_type(manifest_to_import.scoped_short_name,
                                     manifest_to_import.declaration_data)
      end
    end
  end
end
