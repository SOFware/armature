# frozen_string_literal: true

module Armature
  module Snapshot
    class Fingerprint
      def initialize(connection)
        @connection = connection
      end

      def current
        result = @connection.select_value(
          "SELECT MAX(version) FROM schema_migrations"
        )
        Digest::MD5.hexdigest(result.to_s)
      end
    end
  end
end
