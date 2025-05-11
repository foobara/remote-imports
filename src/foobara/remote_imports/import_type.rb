module Foobara
  module RemoteImports
    class ImportType < Command
      include ImportBase

      depends_on ImportDomain, ImportType

      def find_manifests_to_import
        root_manifest.types
      end

      # TODO: break this method up?
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

        # TODO: how do we solve this for :active_record type??
        if declaration_data["type"] == "entity"
          declaration_data = Util.deep_dup(declaration_data)

          declaration_data["type"] = "detached_entity"
          declaration_data["mutable"] = false

          primary_key_attribute = declaration_data["primary_key"]
          required = declaration_data["attributes_declaration"]["required"]

          required << primary_key_attribute unless required.include?(primary_key_attribute)

          model_base_class = declaration_data["model_base_class"]
          unless model_base_class == "Foobara::Entity"
            # :nocov:
            raise "Expected model base class to be Foobara::Entity, but was #{model_base_class}"
            # :nocov:
          end

          declaration_data["model_base_class"] = "Foobara::DetachedEntity"
        end

        type = domain.foobara_type_from_strict_stringified_declaration(declaration_data)

        if deanonymize_models? && type.extends_type?(BuiltinTypes[:model])
          Foobara::Model.deanonymize_class(type.target_class)
        end

        unless domain.foobara_registered?(type)
          domain.foobara_register_type(manifest_to_import.scoped_path, type)
        end

        type
      end

      def deanonymize_models?
        deanonymize_models
      end
    end
  end
end
