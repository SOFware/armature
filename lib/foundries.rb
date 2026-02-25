# frozen_string_literal: true

require "factory_bot"
require_relative "foundries/version"
require_relative "foundries/blueprint"
require_relative "foundries/similarity"
require_relative "foundries/base"

module Foundries
end

require_relative "foundries/snapshot" if defined?(ActiveRecord)
