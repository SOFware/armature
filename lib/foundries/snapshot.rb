# frozen_string_literal: true

require "digest"
require_relative "snapshot/fingerprint"
require_relative "snapshot/adapter"
require_relative "snapshot/adapters/postgres_adapter"
require_relative "snapshot/adapters/sqlite_adapter"
require_relative "snapshot/store"

module Foundries
  module Snapshot
    class << self
      attr_writer :storage_path, :connection, :enabled, :source_paths

      def storage_path
        @storage_path || "tmp/foundries"
      end

      def connection
        @connection || ActiveRecord::Base.connection
      end

      def source_paths
        @source_paths || []
      end

      def enabled?
        return @enabled unless @enabled.nil?
        ENV["FOUNDRIES_CACHE"] == "1"
      end

      def adapter
        @adapter ||= Adapter.for(connection)
      end

      def reset!
        @adapter = nil
        @source_paths = nil
      end
    end
  end
end
