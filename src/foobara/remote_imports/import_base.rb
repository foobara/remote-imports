require "digest/md5"

module Foobara
  module RemoteImports
    module ImportBase
      class BadManifestInputsError < RuntimeError
        class << self
          def context_type_declaration
            {}
          end
        end
      end

      # TODO: why do we need this Value:: prefix?
      class NotFoundError < Value::DataError
        class << self
          def context_type_declaration
            { not_found: [:string] }
          end
        end
      end

      class << self
        def included(klass)
          category = klass.name.match(/Import(\w+)$/)[1]
          category = Util.underscore_sym(category)

          klass.singleton_class.define_method :category do
            category
          end

          klass.possible_input_error :to_import, NotFoundError
          klass.possible_error BadManifestInputsError

          klass.inputs(
            manifest_url: :string,
            raw_manifest: :associative_array,
            cache: { type: :boolean, default: true },
            cache_path: { type: :string, default: "tmp/cache/foobara-remote-imports" },
            to_import: :duck,
            already_imported: { type: :duck, allow_nil: true }
          )

          klass.result :duck
        end
      end

      def execute
        load_manifest

        cache_manifest if should_cache?
        determine_manifests_to_import
        filter_manifests_to_import
        import_objects_from_manifests

        imported_objects
      end

      attr_accessor :manifest_data, :imported_objects, :manifests_to_import

      def validate
        super
        validate_manifest
      end

      def validate_manifest
        if manifest_url
          if raw_manifest
            add_input_error :raw_manifest, :bad_manifest_inputs, "Cannot provide both manifest_url and raw_manifest"
          end
        elsif !raw_manifest
          add_input_error :manifest_url, :bad_manifest_inputs, "Must provide either manifest_url or raw_manifest"
        end
      end

      def already_imported
        inputs[:already_imported] || AlreadyImported.new
      end

      def load_manifest
        self.manifest_data = if raw_manifest
                               raw_manifest
                             elsif cached?
                               load_cached_manifest
                             else
                               load_manifest_from_url
                             end
      end

      def load_manifest_from_url
        # TODO: introduce VCR to test the following elsif block
        # :nocov:
        url = URI.parse(manifest_url)
        response = Net::HTTP.get_response(url)

        manifest_json = if response.is_a?(Net::HTTPSuccess)
                          response.body
                        else
                          raise "Could not get manifest from #{url}: " \
                                "#{response.code} #{response.message}"
                        end

        JSON.parse(manifest_json)
        # :nocov:
      end

      # TODO: feels like a command smell to pass manifests here... reconsider algorithm
      def filter_manifests_to_import
        filter = Util.array(to_import)

        not_found = filter - manifests_to_import.map(&:reference)

        if not_found.any?
          add_input_error :to_import, :not_found, "Could not find #{not_found}", not_found:
        end

        self.manifests_to_import = manifests_to_import.select do |manifest|
          filter.include?(manifest.reference)
        end
      end

      def root_manifest
        @root_manifest ||= Manifest::RootManifest.new(manifest_data)
      end

      def cache_manifest
        FileUtils.mkdir_p(cache_path)
        File.write(cache_file_path, manifest_data.to_json)
      end

      def should_cache?
        cache && manifest_url && !cached?
      end

      def cached?
        File.exist?(cache_file_path)
      end

      def load_cached_manifest
        JSON.parse(File.read(cache_file_path))
      end

      def cache_key
        @cache_key ||= begin
          hash = Digest::MD5.hexdigest(manifest_url)
          escaped_url = manifest_url.gsub(/[^\w]/, "_")

          "#{hash}_#{escaped_url}"
        end
      end

      def cache_file_path
        @cache_file_path ||= "#{cache_path}/#{cache_key}.json"
      end

      def determine_manifests_to_import
        self.manifests_to_import = find_manifests_to_import
      end

      def find_manifests_to_import
        raise "subclass responsibility"
      end

      def import_objects_from_manifests
        manifests_to_import.each do |manifest|
          unless already_imported.already_imported?(manifest)
            imported_objects << import_object_from_manifest(manifest)
            already_imported << manifest
          end
        end
      end

      def import_object_from_manifest(manifest)
        raise "subclass responsibility"
      end

      def imported_objects
        @imported_objects ||= []
      end
    end
  end
end
