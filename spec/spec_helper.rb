# frozen_string_literal: true

require "rspec"
require "active_record"
require "factory_bot"
require "armature"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

ActiveRecord::Schema.define do
  create_table :teams, force: true do |t|
    t.string :name
    t.timestamps
  end

  create_table :users, force: true do |t|
    t.string :name
    t.string :email
    t.string :role
    t.references :team, foreign_key: true
    t.timestamps
  end

  create_table :projects, force: true do |t|
    t.string :name
    t.string :status
    t.references :team, foreign_key: true
    t.timestamps
  end

  create_table :tasks, force: true do |t|
    t.string :name
    t.string :priority
    t.references :project, foreign_key: true
    t.references :user, foreign_key: true
    t.timestamps
  end
end

class Team < ActiveRecord::Base
  has_many :users
  has_many :projects
end

class User < ActiveRecord::Base
  belongs_to :team, optional: true
  has_many :tasks
end

class Project < ActiveRecord::Base
  belongs_to :team, optional: true
  has_many :tasks
end

class Task < ActiveRecord::Base
  belongs_to :project, optional: true
  belongs_to :user, optional: true
end

FactoryBot.define do
  factory :team do
    sequence(:name) { |n| "Team #{n}" }
  end

  factory :user do
    sequence(:name) { |n| "User #{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    role { "member" }

    trait :admin do
      role { "admin" }
    end
  end

  factory :project do
    sequence(:name) { |n| "Project #{n}" }
    status { "active" }
  end

  factory :task do
    sequence(:name) { |n| "Task #{n}" }
    priority { "normal" }
  end
end

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  config.around do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end
end
