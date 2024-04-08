module Foobara
  module RemoteImports
    class AlreadyImported
      def imported
        @imported ||= Set.new
      end

      def <<(manifest)
        imported << to_key(manifest)
      end

      def to_key(manifest)
        [manifest.path.first.to_sym, manifest.reference.to_sym]
      end

      def already_imported?(manifest)
        imported.include?(to_key(manifest))
      end
    end
  end
end
