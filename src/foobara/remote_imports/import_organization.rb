module Foobara
  module RemoteImports
    class ImportOrganization < Command
      include ImportBase

      def find_manifests_to_import
         root_manifest.organizations
      end

      def import_object_from_manifest(manifest)
        Organization.create(manifest.reference)
      end
    end
  end
end
