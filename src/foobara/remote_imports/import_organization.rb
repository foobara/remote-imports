require "digest/md5"

module Foobara
  module RemoteImports
    class ImportOrganization < Foobara::Command
      class BadManifestInputs < RuntimeError
        class << self
          def context_type_declaration
            {}
          end
        end
      end

      class OrganizationNotFound < RuntimeError
        class << self
          def context_type_declaration
            { not_found: [:string] }
          end
        end
      end

      inputs do
        manifest_url :string
        raw_manifest :string
        cache :boolean, default: true
        cache_path :string, default: "tmp/cache/foobara-remote-imports"
        organization :duck
      end

      result :duck

      def execute
        load_manifest
        cache_manifest
        determine_organization_manifests_to_import
        import_organization_manifests

        imported_organizations
      end

      attr_accessor :manifest_data, :organization_manifests

      def validate
        super
        validate_manifest
      end

      def validate_manifest
        if manifest_url
          if raw_manifest
            add_input_error :raw_manifest, "Cannot provide both manifest_url and raw_manifest"
          end
        elsif !raw_manifest
          add_input_error :manifest_url, "Must provide either manifest_url or raw_manifest"
        end
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

      def root_manifest
        @root_manifest ||= Manifest::RootManifest.new(manifest_data)
      end

      def cache_manifest
        if cache
          FileUtils.mkdir_p(cache_path)
          File.write(cache_file_path, manifest_data.to_json)
        end
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

      def determine_organization_manifests_to_import
        self.organization_manifests = if organization
                                        organizations = root_manifest.organizations

                                        filter = Util.array(organization)

                                        not_found = filter - organizations.map(&:reference)

                                        if not_found.any?
                                          add_input_error :organization, :organization_not_found, not_found:
                                        end

                                        organizations.select do |organization_manifest|
                                          filter.include?(organization_manifest.reference)
                                        end
                                      else
                                        root_manifest.organizations
                                      end
      end

      def import_organization_manifests
        organization_manifests.each do |organization_manifest|
          imported_organizations << Domain.create_organization(organization_manifest.reference)
        end
      end

      def imported_organizations
        @imported_organizations ||= []
      end
    end
  end
end
