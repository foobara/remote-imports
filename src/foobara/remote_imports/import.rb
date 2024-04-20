require_relative "import_domain"
require_relative "import_type"
require_relative "import_error"
require_relative "../remote_command"

module Foobara
  module RemoteImports
    class Import < Command
      inputs do
        manifest BaseManifest
        already_imported AlreadyImported
      end

      depends_on ImportDomain, ImportType, ImportError, ImportCommand, ImportOrganization

      result :duck

      def execute
        determine_import_command_class
        build_command
        run_import_command
      end

      attr_accessor :import_command_class, :command

      def determine_import_command_class
        self.import_command_class = manifest_to_command_class(manifest_to_import)
      end

      def run_import_command
        run_subcommand!(
          import_command_class,
          raw_manifest: manifest.relevant_manifest,
          to_import: manifest.reference,
          already_imported:
        )
      end

      def manifest_to_command_class(manifest)
        case manifest
        when Manifest::Command
          ImportCommand
        when Manifest::Domain
          ImportDomain
        when Manifest::Organization
          ImportOrganization
        when Manifest::Type
          ImportType
        when Manifest::Error
          ImportError
        else
          # :nocov:
          raise "Unknown manifest type: #{manifest}"
          # :nocov:
        end
      end
    end
  end
end
