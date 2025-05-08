require_relative "remote_command"

module Foobara
  class AuthenticatedRemoteCommand < RemoteCommand
    class << self
      attr_accessor :auth_header_name, :auth_header_value

      def subclass(auth_header:, **opts)
        super(base: AuthenticatedRemoteCommand, **opts).tap do |klass|
          klass.auth_header_name = auth_header[0]
          klass.auth_header_value = auth_header[1]
        end
      end
    end

    def build_request_headers
      value = self.class.auth_header_value

      if value.is_a?(Proc)
        value = if value.lambda? && value.arity == 0
                  value.call
                else
                  value.call(self)
                end
      end

      self.request_headers = super.merge(self.class.auth_header_name => value)
    end
  end
end
