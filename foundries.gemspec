# frozen_string_literal: true

require_relative "lib/foundries/version"

Gem::Specification.new do |spec|
  spec.name = "foundries"
  spec.version = Foundries::VERSION
  spec.authors = ["John Dowd", "Jim Gay"]
  spec.email = ["john.dowd@sofwarellc.com", "jim.gay@sofwarellc.com"]

  spec.summary = "Declarative trees of related data using factory_bot"
  spec.description = "Compose factory_bot factories into foundries that build complex trees of related records with a declarative DSL."
  spec.homepage = "https://github.com/SOFware/foundries"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata = {
    "allowed_push_host" => "https://rubygems.org",
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "https://github.com/SOFware/foundries/blob/main/CHANGELOG.md"
  }

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{lib}/**/*", "Rakefile", "LICENSE", "CHANGELOG.md", "README.md"]
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "factory_bot", ">= 6.0"
  spec.add_dependency "ostruct"
end
