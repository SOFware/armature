# frozen_string_literal: true

module Armature
  module Snapshot
    class Fingerprint
      def initialize(connection, source_paths: [])
        @connection = connection
        @source_paths = Array(source_paths)
      end

      def current
        digest = Digest::MD5.new
        digest.update(schema_version)
        @source_paths.sort.each do |path|
          digest.update(File.read(path)) if File.exist?(path)
        end
        digest.hexdigest
      end

      private

      def schema_version
        @connection.select_value(
          "SELECT MAX(version) FROM schema_migrations"
        ).to_s
      end
    end
  end
end
