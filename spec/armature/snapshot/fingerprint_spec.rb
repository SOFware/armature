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

  describe "source_paths" do
    let(:tmpdir) { Dir.mktmpdir("fingerprint_test") }
    let(:source_file) { File.join(tmpdir, "foundry.rb") }

    before do
      ActiveRecord::Base.connection.execute(
        "INSERT INTO schema_migrations (version) VALUES ('20240101000000')"
      )
    end

    after { FileUtils.rm_rf(tmpdir) }

    it "changes fingerprint when source file content changes" do
      File.write(source_file, "class Foo; end")
      fp1 = described_class.new(ActiveRecord::Base.connection, source_paths: [source_file])
      first = fp1.current

      File.write(source_file, "class Bar; end")
      fp2 = described_class.new(ActiveRecord::Base.connection, source_paths: [source_file])
      second = fp2.current

      expect(first).not_to eq second
    end

    it "is stable when source files are unchanged" do
      File.write(source_file, "class Foo; end")
      fp = described_class.new(ActiveRecord::Base.connection, source_paths: [source_file])

      expect(fp.current).to eq fp.current
    end

    it "is deterministic regardless of path order" do
      file_a = File.join(tmpdir, "a.rb")
      file_b = File.join(tmpdir, "b.rb")
      File.write(file_a, "aaa")
      File.write(file_b, "bbb")

      fp1 = described_class.new(ActiveRecord::Base.connection, source_paths: [file_a, file_b])
      fp2 = described_class.new(ActiveRecord::Base.connection, source_paths: [file_b, file_a])

      expect(fp1.current).to eq fp2.current
    end

    it "skips missing files" do
      fp = described_class.new(
        ActiveRecord::Base.connection,
        source_paths: [File.join(tmpdir, "nonexistent.rb")]
      )

      expect(fp.current).to be_a(String)
      expect(fp.current.length).to eq 32
    end

    it "matches schema-only fingerprint when source_paths is empty" do
      schema_only = described_class.new(ActiveRecord::Base.connection)
      with_empty = described_class.new(ActiveRecord::Base.connection, source_paths: [])

      expect(schema_only.current).to eq with_empty.current
    end
  end
end
