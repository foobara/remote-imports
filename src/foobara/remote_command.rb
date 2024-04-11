module Foobara
  class RemoteCommand < Command
    # TODO: fill this out
    class << self
      attr_accessor :url

      def subclass(
        url:,
        description:,
        inputs:,
        result:,
        possible_errors:,
        name:,
        base: self
      )
        klass = Util.make_class_p(name, base)

        klass.url = url
        klass.description description
        klass.inputs inputs
        klass.result result

        possible_errors.each_value do |possible_error_manifest|
          error_class_name = possible_error_manifest.error.reference

          error_class = Foobara.foobara_root_namespace.foobara_lookup_error!(error_class_name)
          key = possible_error_manifest.key
          path = possible_error_manifest.path
          symbol = possible_error_manifest.symbol
          data = possible_error_manifest.processor_manifest_data

          category = possible_error_manifest.category

          possible_error = PossibleError.new(error_class, symbol:, data:, key:, category:)
          possible_error.prepend_path!(path)

          register_possible_error_class(possible_error)
        end

        klass
      end
    end
  end
end
