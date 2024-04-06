module Foobara
  module RemoteImports
    class ImportDomain < Command
      include ImportBase

      depends_on ImportOrganization

      def find_manifests_to_import
        domains = root_manifest.domains

        organizations = domains.map(&:organization).uniq

        [*organizations, *domains]
      end

      def import_object_from_manifest
        case manifest_to_import
        when Manifest::Organization
          run_subcommand!(
            ImportOrganization,
            raw_manifest: manifest_data,
            to_import: manifest_to_import.reference,
            already_imported:
          )
        when Manifest::Domain
          Domain.create(manifest_to_import.reference)
        else
          raise "Not sure how to import #{manifest_to_import}"
        end
      end
    end
  end
end
