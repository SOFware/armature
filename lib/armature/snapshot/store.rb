# frozen_string_literal: true

require "fileutils"
require "pathname"

module Armature
  module Snapshot
    class Store
      def initialize(preset_name, adapter: Snapshot.adapter,
        storage_path: Snapshot.storage_path,
        source_paths: Snapshot.source_paths)
        @preset_name = preset_name.to_s
        @adapter = adapter
        @storage_path = storage_path
        @fingerprint = Fingerprint.new(
          adapter.instance_variable_get(:@connection),
          source_paths: source_paths
        )
      end

      def cached?
        cache_dir.exist? &&
          cache_dir.join(".fingerprint").exist? &&
          cache_dir.join(".fingerprint").read.strip == @fingerprint.current
      end

      # Record which tables are empty before the preset block runs.
      # Only these tables will be captured after the block completes.
      def record_empty_tables
        @capturable_tables = @adapter.table_names.select { |t| @adapter.empty?(t) }
      end

      def capture
        tables = @capturable_tables || @adapter.table_names

        tmp_dir = Pathname.new("#{cache_dir}.#{$$}.tmp")
        tmp_dir.mkpath

        tables.each do |table|
          tmp_dir.join("#{table}.dat").open("w") do |f|
            @adapter.capture(table, f)
          end
        end

        tmp_dir.join(".fingerprint").write(@fingerprint.current)

        # Atomic swap
        FileUtils.rm_rf(cache_dir) if cache_dir.exist?
        FileUtils.mv(tmp_dir, cache_dir)
      end

      def restore
        @adapter.disable_referential_integrity do
          cache_dir.glob("*.dat").each do |file|
            next unless file.size > 0

            table = file.basename(".dat").to_s
            file.open("r") do |f|
              @adapter.restore(table, f)
            end
            @adapter.reset_sequence(table)
          end
        end
      end

      private

      def cache_dir
        @cache_dir ||= Pathname.new(@storage_path).join(@preset_name)
      end
    end
  end
end
