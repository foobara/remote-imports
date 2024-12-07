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

        # TODO: might this be a sign of a name collision? Maybe better to give a meaningful error if the type isn't in
        # #already_imported ??
        return if existing_type

        domain_manifest = manifest_to_import.domain

        run_subcommand!(
          ImportDomain,
          raw_manifest: manifest_data,
          to_import: domain_manifest.reference,
          already_imported:
        )

        domain_manifest = manifest_to_import.domain

        domain = if domain_manifest.global?
                   GlobalDomain
                 else
                   Foobara.foobara_root_namespace.foobara_lookup_domain!(
                     domain_manifest.reference,
                     mode: Namespace::LookupMode::ABSOLUTE
                   )
                 end

        manifest_to_import.types_depended_on.each do |depended_on_type|
          run_subcommand!(
            ImportType,
            raw_manifest: manifest_data,
            to_import: depended_on_type.reference,
            already_imported:
          )
        end

        containing_module_name = manifest_to_import.scoped_full_path[0..-2].join("::")
        unless containing_module_name.empty?
          Util.make_module_p(containing_module_name, tag: true)
        end

        # Warning: cannot desugarize this because unfortunately desugarizing an entity declaration will actually
        # create the entity class, which should be considered a bug.
        declaration_data = manifest_to_import.declaration_data

        type = domain.foobara_type_from_strict_stringified_declaration(declaration_data)
        domain.foobara_register_type(manifest_to_import.scoped_path, type)
      end
    end
  end
end
