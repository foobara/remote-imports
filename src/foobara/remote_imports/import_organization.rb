require_relative "import_base"

module Foobara
  module RemoteImports
    class ImportOrganization < Command
      include ImportBase

      def find_manifests_to_import
        root_manifest.organizations
      end

      def import_object_from_manifest
        Organization.create(manifest_to_import.reference)
      end
    end
  end
end
