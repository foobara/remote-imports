require_relative "remote_command"

module Foobara
  class AuthenticatedRemoteCommand < RemoteCommand
    class << self
      attr_accessor :authenticate_with_header_name, :authenticate_with_header_value

      def subclass(authenticate_with_header:, **opts)
        super(base: AuthenticatedRemoteCommand, **opts).tap do |klass|
          klass.authenticate_with_header_name = authenticate_with_header[:name]
          klass.authenticate_with_header_value = authenticate_with_header[:value]
        end
      end
    end

    def build_request_headers
      value = self.class.authenticate_with_header_value

      if value.is_a?(Proc)
        value = if value.lambda? && value.arity == 0
                  value.call
                else
                  value.call(self)
                end
      end

      self.request_headers = super.merge(self.class.authenticate_with_header_name => value)
    end
  end
end
