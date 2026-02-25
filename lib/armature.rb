# frozen_string_literal: true

require "factory_bot"
require_relative "armature/version"
require_relative "armature/blueprint"
require_relative "armature/similarity"
require_relative "armature/base"

module Armature
end

require_relative "armature/snapshot" if defined?(ActiveRecord)
