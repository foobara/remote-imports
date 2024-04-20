module Foobara
  module RemoteImports
    class ImportDomain < Command
      include ImportBase

      depends_on ImportOrganization

      def find_manifests_to_import
        root_manifest.domains
      end

      def import_object_from_manifest
        if manifest_to_import.global?
          return GlobalDomain
        end

        organization = manifest_to_import.organization

        run_subcommand!(
          ImportOrganization,
          raw_manifest: manifest_data,
          to_import: organization.reference,
          already_imported:
        )

        Domain.create(manifest_to_import.reference)
      end
    end
  end
end
