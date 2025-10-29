require "digest/md5"
require "fileutils"
require "json"
require "net/http"

module Foobara
  module RemoteImports
    module ImportBase
      # Why doesn't this automatically register the possible error??
      class BadManifestInputsError < Foobara::RuntimeError
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
          klass.possible_input_error :to_import, NotFoundError
          klass.possible_error BadManifestInputsError

          klass.inputs(
            manifest_url: :string,
            raw_manifest: :associative_array,
            cache: { type: :boolean, default: true },
            cache_path: { type: :string, default: "tmp/cache/foobara-remote-imports" },
            to_import: :duck,
            already_imported: { type: :duck, allow_nil: true },
            deanonymize_models: { type: :boolean, default: true }
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

      attr_accessor :manifest_data, :manifests_to_import, :manifest_to_import

      def validate
        super
        validate_manifest
      end

      def validate_manifest
        if manifest_url
          if raw_manifest
            add_runtime_error :bad_manifest_inputs, "Cannot provide both manifest_url and raw_manifest"
          end
        elsif !raw_manifest
          add_runtime_error :bad_manifest_inputs, "Must provide either manifest_url or raw_manifest"
        end
      end

      def already_exists?
        method = "foobara_lookup_#{manifest_to_import.scoped_category}"

        Foobara.foobara_root_namespace.send(
          method,
          manifest_to_import.reference,
          mode: Namespace::LookupMode::ABSOLUTE
        )
      end

      def already_imported
        inputs[:already_imported] || AlreadyImported.new
      end

      def load_manifest
        self.manifest_data = if raw_manifest
                               raw_manifest
                             elsif cache && cached?
                               load_cached_manifest
                             else
                               load_manifest_from_url
                             end
      end

      def load_manifest_from_url
        uri = URI.parse(manifest_url)

        net_http = Net::HTTP.new(uri.host, uri.port).tap do |http|
          http.use_ssl = uri.scheme == "https"
          http.read_timeout = ENV["FOOBARA_HTTP_MANIFEST_TIMEOUT"]&.to_i || 30
        end

        request = Net::HTTP::Get.new(uri.request_uri, load_manifest_headers)
        response = net_http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          # :nocov:
          raise "Could not get manifest from #{manifest_url}: " \
                "#{response.code} #{response.message}"
          # :nocov:
        end
        manifest_json = response.body

        JSON.parse(manifest_json)
      end

      def load_manifest_headers
        { "Content-Type" => "application/json" }
      end

      # TODO: feels like a command smell to pass manifests here... reconsider algorithm
      def filter_manifests_to_import
        return if to_import.nil? || to_import.empty?

        references = manifests_to_import.map(&:reference)

        filter = Util.array(to_import)

        filter.map! do |name|
          if references.include?(name)
            name
          else
            suffix = "::#{name}"

            partial_matches = references.select { |reference| reference.end_with?(suffix) }

            if partial_matches.size == 1
              partial_matches.first
            else
              name
            end
          end
        end

        not_found = filter - references

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
        # :nocov:
        raise "subclass responsibility"
        # :nocov:
      end

      def import_objects_from_manifests
        manifests_to_import.each do |manifest|
          unless already_imported.already_imported?(manifest)
            self.manifest_to_import = manifest

            next if already_exists?

            imported_objects << import_object_from_manifest
            already_imported << manifest
          end
        end
      end

      def import_object_from_manifest
        # :nocov:
        raise "subclass responsibility"
        # :nocov:
      end

      def imported_objects
        @imported_objects ||= []
      end
    end
  end
end
