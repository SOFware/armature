# frozen_string_literal: true

require "spec_helper"

RSpec.describe Armature::Snapshot::Fingerprint do
  before do
    ActiveRecord::Base.connection.execute(<<~SQL)
      CREATE TABLE IF NOT EXISTS schema_migrations (version VARCHAR NOT NULL)
    SQL
    ActiveRecord::Base.connection.execute("DELETE FROM schema_migrations")
  end

  let(:fingerprint) { described_class.new(ActiveRecord::Base.connection) }

  it "computes a fingerprint from schema_migrations" do
    ActiveRecord::Base.connection.execute(
      "INSERT INTO schema_migrations (version) VALUES ('20240101000000')"
    )

    expect(fingerprint.current).to be_a(String)
    expect(fingerprint.current.length).to eq 32 # MD5 hex digest
  end

  it "changes when schema_migrations changes" do
    ActiveRecord::Base.connection.execute(
      "INSERT INTO schema_migrations (version) VALUES ('20240101000000')"
    )
    first = fingerprint.current

    ActiveRecord::Base.connection.execute(
      "INSERT INTO schema_migrations (version) VALUES ('20240202000000')"
    )
    second = fingerprint.current

    expect(first).not_to eq second
  end

  it "is stable for the same schema" do
    ActiveRecord::Base.connection.execute(
      "INSERT INTO schema_migrations (version) VALUES ('20240101000000')"
    )

    expect(fingerprint.current).to eq fingerprint.current
  end
end
