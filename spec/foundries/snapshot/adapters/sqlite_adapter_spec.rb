# frozen_string_literal: true

require "spec_helper"

RSpec.describe Foundries::Snapshot::Adapters::SqliteAdapter do
  let(:connection) { ActiveRecord::Base.connection }
  let(:adapter) { described_class.new(connection) }

  describe "#capture and #restore" do
    it "round-trips table data through IO" do
      create(:team, name: "Alpha")
      create(:team, name: "Bravo")

      io = StringIO.new
      adapter.capture("teams", io)

      expect(io.string).to include("Alpha")
      expect(io.string).to include("Bravo")

      # Delete originals
      connection.execute("DELETE FROM teams")
      expect(Team.count).to eq 0

      # Restore
      io.rewind
      adapter.restore("teams", io)
      expect(Team.count).to eq 2
      expect(Team.pluck(:name)).to contain_exactly("Alpha", "Bravo")
    end

    it "handles empty tables" do
      io = StringIO.new
      adapter.capture("teams", io)

      expect(io.string).to be_empty
    end
  end

  describe "#disable_referential_integrity" do
    it "yields the block" do
      called = false
      adapter.disable_referential_integrity { called = true }
      expect(called).to be true
    end
  end
end
