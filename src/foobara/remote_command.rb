require "json"
require "net/http"

require "foobara/command_connectors"

module Foobara
  class RemoteCommand < Command
    class UnexpectedError < StandardError; end

    class << self
      attr_accessor :url_base

      def subclass(
        url_base:,
        description:,
        inputs:,
        result:,
        possible_errors:,
        name:,
        base: RemoteCommand
      )
        klass = Util.make_class_p(name, base)
        klass.url_base = url_base
        klass.description description
        klass.inputs inputs
        klass.result result

        possible_errors.each_value do |possible_error_manifest|
          error_class_name = possible_error_manifest.error.reference

          error_class = Foobara.foobara_root_namespace.foobara_lookup_error!(error_class_name)
          key = possible_error_manifest.key
          symbol = possible_error_manifest.symbol
          data = possible_error_manifest.processor_manifest_data

          category = possible_error_manifest.category

          possible_error = PossibleError.new(error_class, symbol:, data:, key:, category:)

          if possible_error_manifest.manually_added
            possible_error.manually_added = true
          end

          klass.register_possible_error_class(possible_error)
        end

        klass
      end

      def url
        @url ||= "#{url_base}/run/#{name}"
      end
    end

    # We need to override this method and let the receiving end perform most of the casting.
    # One exception is we will find and convert all records to their primary key values instead of sending
    # serialized records over the wire.
    def cast_and_validate_inputs
      @inputs = if inputs_type.nil? && (raw_inputs.nil? || raw_inputs.empty?)
                  # TODO: test this path
                  # :nocov:
                  {}
                  # :nocov:
                else
                  serializer_class = CommandConnectors::Serializers::EntitiesToPrimaryKeysSerializer
                  serializer = serializer_class.new(detached_to_primary_key: true)
                  serializer.serialize(raw_inputs)
                end
    end

    # Handling transactions across systems is too much to attempt for now and maybe ever.
    # So let's noop several of these
    [
      :auto_detect_current_transactions,
      :relevant_entity_classes,
      :open_transaction,
      :rollback_transaction,
      :commit_transaction
    ].each do |method_name|
      define_method(method_name) { nil }
    end

    def url
      self.class.url
    end

    def execute
      build_request_body
      build_request_headers
      # TODO: implement this for queries?
      #      build_query_string
      issue_http_request
      parse_response

      parsed_result
    end

    attr_accessor :request_body, :request_headers, :response, :response_body, :response_code, :parsed_result

    def build_request_body
      self.request_body = inputs
    end

    def build_request_headers
      self.request_headers = {
        "Content-Type" => "application/json"
      }
    end

    def issue_http_request
      url = URI.parse(self.url)
      self.response = Net::HTTP.post(url, JSON.generate(request_body), request_headers)
    end

    def parse_response
      self.response_body = response.body
      self.response_code = response.code

      if response.is_a?(Net::HTTPSuccess)
        self.parsed_result = JSON.parse(response_body)
      elsif response.code.start_with?("4")
        errors = JSON.parse(response_body)
        errors.each do |error|
          case error["category"]
          when "runtime"
            e = add_runtime_error(
              symbol: error["symbol"],
              message: error["message"],
              context: error["context"],
              halt: false
            )
            e.runtime_path = error["runtime_path"]
          when "data"
            add_input_error(
              symbol: error["symbol"],
              message: error["message"],
              context: error["context"],
              path: error["path"]
            )
          else
            # :nocov:
            raise "Bad error category: #{error["category"]}"
            # :nocov:
          end
        end

        halt!
      else
        # :nocov:
        raise UnexpectedError, "#{response.code} from #{url}: #{response.body}"
        # :nocov:
      end
    end
  end
end
