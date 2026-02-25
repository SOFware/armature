# frozen_string_literal: true

module Foundries
  module Snapshot
    module Adapter
      def self.for(connection)
        case connection.adapter_name
        when /postgresql/i
          Adapters::PostgresAdapter.new(connection)
        when /sqlite/i
          Adapters::SqliteAdapter.new(connection)
        else
          raise "Unsupported adapter: #{connection.adapter_name}"
        end
      end
    end
  end
end
