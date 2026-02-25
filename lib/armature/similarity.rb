# frozen_string_literal: true

require_relative "similarity/structure_tree"
require_relative "similarity/recorder"
require_relative "similarity/comparator"

module Armature
  module Similarity
    class << self
      attr_writer :enabled

      def enabled?
        return @enabled unless @enabled.nil?
        ENV["ARMATURE_SIMILARITY"] == "1"
      end

      def registry
        @registry ||= {}
      end

      def warned_pairs
        @warned_pairs ||= Set.new
      end

      def reset!
        @registry = {}
        @warned_pairs = Set.new
        @enabled = nil
      end
    end
  end
end
