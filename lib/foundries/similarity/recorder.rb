# frozen_string_literal: true

require_relative "structure_tree"

module Foundries
  module Similarity
    class Recorder
      def initialize
        @root = StructureTree.root(children: [])
        @stack = [@root]
      end

      def record(method_name, has_block:)
        node = StructureTree.new(method_name)
        current_parent.children << node
        if has_block
          @stack.push(node)
          yield
          @stack.pop
        elsif block_given?
          yield
        end
      end

      def normalized_tree
        @root.normalize
      end

      private

      def current_parent
        @stack.last
      end
    end
  end
end
