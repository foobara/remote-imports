module Foobara
  module RemoteImports
    class ImportType < Command
      include ImportBase

      depends_on ImportDomain

      def find_manifests_to_import
        root_manifest.types
      end

      def import_object_from_manifest
        domain_manifest = manifest_to_import.domain

        run_subcommand!(
          ImportDomain,
          raw_manifest: manifest_data,
          to_import: domain_manifest.reference,
          already_imported:
        )

        existing_type = Foobara.foobara_root_namespace.foobara_lookup_type(
          manifest_to_import.reference,
          mode: Namespace::LookupMode::ABSOLUTE
        )

        unless existing_type
          domain = Foobara.foobara_root_namespace.foobara_lookup_domain!(
            manifest_to_import.domain.reference,
            mode: Namespace::LookupMode::ABSOLUTE
          )

          domain.foobara_register_type(manifest_to_import.scoped_short_name, manifest_to_import.declaration_data)
        end
      end
    end
  end
end
