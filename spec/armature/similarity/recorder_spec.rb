# frozen_string_literal: true

require "spec_helper"
require "armature/similarity/recorder"

RSpec.describe Armature::Similarity::Recorder do
  subject(:recorder) { described_class.new }

  def tree(name, children: [])
    Armature::Similarity::StructureTree.new(name, children: children)
  end

  describe "#record" do
    it "records top-level calls" do
      recorder.record("user", has_block: false) {}
      recorder.record("project", has_block: false) {}

      result = recorder.normalized_tree
      expect(result.children.map(&:name)).to eq %w[project user]
    end

    it "records nested calls in correct tree structure" do
      recorder.record("team", has_block: true) do
        recorder.record("user", has_block: false) {}
        recorder.record("project", has_block: true) do
          recorder.record("task", has_block: false) {}
        end
      end

      result = recorder.normalized_tree
      team = result.children.first
      expect(team.name).to eq "team"
      expect(team.children.map(&:name)).to eq %w[project user]
      expect(team.children.first.children.map(&:name)).to eq %w[task]
    end

    it "normalizes the result" do
      recorder.record("team", has_block: true) do
        recorder.record("z_user", has_block: false) {}
        recorder.record("a_admin", has_block: false) {}
      end

      result = recorder.normalized_tree
      expect(result.children.first.children.map(&:name)).to eq %w[a_admin z_user]
    end
  end
end
