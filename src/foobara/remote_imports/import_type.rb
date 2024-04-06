module Foobara
  module RemoteImports
    class ImportType < Command
      include ImportBase

      depends_on ImportDomain

      def find_manifests_to_import
        types = root_manifest.types

        domains = types.map(&:domain).uniq
        [*domains, *types]
      end

      def import_object_from_manifest
        if manifest_to_import.is_a?(Manifest::Type)
          manifest_to_import
        else
          subcommand = case manifests_to_import
                       when Manifest::Domain
                         ImportDomain
                       when Manifest::Type
                         ImportType
                       end

          if subcommand
            run_subcommand!(
              subcommand,
              raw_manifest: manifest_data,
              to_import: manifest_to_import.reference,
              already_imported:
            )
          else
            raise "Not sure how to import #{manifest_to_import}"
          end
        end
      end
    end
  end
end
