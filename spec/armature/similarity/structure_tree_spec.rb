# frozen_string_literal: true

require "spec_helper"
require "armature/similarity/structure_tree"

RSpec.describe Armature::Similarity::StructureTree do
  def tree(name, children: [])
    described_class.new(name, children: children)
  end

  describe "#normalize" do
    it "sorts children alphabetically" do
      root = tree("root", children: [tree("z"), tree("a"), tree("m")])
      normalized = root.normalize

      expect(normalized.children.map(&:name)).to eq %w[a m z]
    end

    it "deduplicates children by name" do
      root = tree("root", children: [tree("a"), tree("a"), tree("b")])
      normalized = root.normalize

      expect(normalized.children.map(&:name)).to eq %w[a b]
    end

    it "keeps the richest subtree when deduplicating" do
      shallow = tree("child")
      deep = tree("child", children: [tree("grandchild")])
      root = tree("root", children: [shallow, deep])
      normalized = root.normalize

      expect(normalized.children.size).to eq 1
      expect(normalized.children.first.children.size).to eq 1
    end

    it "normalizes recursively" do
      inner = tree("inner", children: [tree("z"), tree("a")])
      root = tree("root", children: [inner])
      normalized = root.normalize

      expect(normalized.children.first.children.map(&:name)).to eq %w[a z]
    end
  end

  describe "structural equality" do
    it "considers trees with same structure equal" do
      a = tree("root", children: [tree("child")])
      b = tree("root", children: [tree("child")])

      expect(a).to eq b
      expect(a.hash).to eq b.hash
    end

    it "considers trees with different structure not equal" do
      a = tree("root", children: [tree("child")])
      b = tree("root", children: [tree("other")])

      expect(a).not_to eq b
    end

    it "considers trees with different depth not equal" do
      a = tree("root", children: [tree("child")])
      b = tree("root", children: [tree("child", children: [tree("grandchild")])])

      expect(a).not_to eq b
    end
  end

  describe "#contains?" do
    it "returns true when subtree matches exactly" do
      child = tree("child", children: [tree("grandchild")])
      root = tree("root", children: [child])

      expect(root.contains?(child)).to be true
    end

    it "returns true for exact match" do
      a = tree("root", children: [tree("child")])
      b = tree("root", children: [tree("child")])

      expect(a.contains?(b)).to be true
    end

    it "returns true when other is a simpler version of the same shape" do
      large = tree("root", children: [
        tree("team", children: [tree("user"), tree("project")])
      ])
      small = tree("root", children: [tree("team")])

      expect(large.contains?(small)).to be true
    end

    it "returns false when no subtree matches" do
      root = tree("root", children: [tree("a")])
      other = tree("b", children: [tree("c")])

      expect(root.contains?(other)).to be false
    end

    it "finds deeply nested subtrees" do
      leaf = tree("leaf")
      mid = tree("mid", children: [leaf])
      root = tree("root", children: [mid])

      expect(root.contains?(leaf)).to be true
    end
  end

  describe "#to_s" do
    it "renders a leaf node" do
      expect(tree("user").to_s).to eq "user"
    end

    it "renders a nested tree" do
      root = tree("team", children: [
        tree("project", children: [tree("task")]),
        tree("user")
      ])

      expect(root.to_s).to eq "team > [project > [task], user]"
    end
  end

  describe "edge cases" do
    it "handles empty tree" do
      empty = tree("root")

      expect(empty.normalize).to eq empty
      expect(empty.descendant_count).to eq 0
      expect(empty.to_s).to eq "root"
    end

    it "handles single node" do
      single = tree("only")

      expect(single.normalize).to eq single
      expect(single.contains?(single)).to be true
    end
  end

  describe ".root" do
    it "creates a synthetic root node" do
      root = described_class.root(children: [tree("a"), tree("b")])

      expect(root.name).to eq "__root__"
      expect(root.children.size).to eq 2
    end
  end
end
