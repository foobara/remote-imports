require_relative "import_domain"
require_relative "import_type"

module Foobara
  module RemoteImports
    class ImportCommand < Command
      include ImportBase

      depends_on ImportDomain, ImportType

      def find_manifests_to_import
        commands = root_manifest.commands

        domains = commands.map(&:domain).uniq
        types = commands.map(&:types_depended_on).flatten

        [*domains, *types, *commands]
      end

      def import_object_from_manifest
        if manifest_to_import.is_a?(Manifest::Command)
          RemoteCommand.create(manifest_to_import)
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
