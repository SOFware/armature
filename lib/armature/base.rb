# frozen_string_literal: true

require "ostruct"

module Armature
  # Base is the orchestrator that composes multiple Blueprints into a single
  # declarative builder for trees of related records.
  #
  # Subclass Base and declare which blueprints it uses:
  #
  #   class MyArmature < Armature::Base
  #     blueprint UserBlueprint
  #     blueprint ProjectBlueprint
  #
  #     # Optional: additional collections beyond what blueprints declare
  #     collection :tags
  #   end
  #
  #   MyArmature.new do
  #     user "Alice" do
  #       project "Widget" do
  #         # ...
  #       end
  #     end
  #   end
  #
  class Base
    include FactoryBot::Syntax::Methods

    class << self
      # Register a blueprint class with this foundry.
      def blueprint(klass)
        blueprint_registry[klass] = klass.handled_methods
      end

      # All registered blueprint classes and their handled methods.
      def blueprint_registry
        @blueprint_registry ||= {}
      end

      # Declare additional collection names beyond those from blueprints.
      def collection(*names)
        extra_collections.concat(names.map(&:to_s))
      end

      def extra_collections
        @extra_collections ||= []
      end

      # All collection accessor names (e.g. "users_collection").
      def collection_accessors
        (blueprint_collection_names + extra_collections).map { |name| "#{name}_collection" }
      end

      # Collection names derived from blueprint declarations.
      def blueprint_collection_names
        blueprint_registry.keys.filter_map { |klass| klass.collection_name&.to_s }
      end

      # Methods delegated from this foundry to its blueprint instances.
      def delegations
        blueprint_registry.select { |_, methods| methods.any? }
      end

      # Define presets — named class methods that build a preconfigured foundry.
      #
      #   class MyArmature < Armature::Base
      #     preset :full_team do
      #       user "Alice"
      #       user "Bob"
      #     end
      #   end
      #
      #   MyFoundry.full_team  # => configured foundry instance
      #
      def preset(name, &block)
        define_singleton_method(name) do
          if defined?(Armature::Snapshot) && Armature::Snapshot.enabled?
            store = Armature::Snapshot::Store.new(name)

            if store.cached?
              store.restore
              return new # hollow — no block, data already in DB
            end

            store.record_empty_tables
            foundry = new(&block)
            store.capture
            foundry
          else
            new(&block)
          end
        end
      end

      def inherited(subclass)
        super
        # Ensure subclasses get their own registries
        subclass.instance_variable_set(:@blueprint_registry, {})
        subclass.instance_variable_set(:@extra_collections, [])
      end
    end

    def initialize(&block)
      instantiate_blueprints
      initialize_collections
      @current = OpenStruct.new(resource: self)
      setup
      instance_exec(&block) if block
      teardown
      @current.resource = nil
    end

    attr_accessor :current

    # Reopen the foundry to add more records.
    def reopen(&block)
      @current = OpenStruct.new(resource: self)
      instance_exec(&block) if block
      teardown
      @current.resource = nil
      self
    end

    # Build within the context of existing objects.
    def from(objects, &block)
      execute_and_restore_state do
        load_existing_objects(objects)
        instance_exec(&block) if block
        teardown
      end
    end

    def load_existing_objects(objects)
      return if objects.nil? || (objects.respond_to?(:empty?) && objects.empty?)

      Array(objects).each do |object|
        load_state(object)

        klass_name = object.class.name
        blueprint_class = find_blueprint_class_for(klass_name)
        next unless blueprint_class

        blueprint_class.load_state_from(object, self)
      end
    end

    def execute_and_restore_state
      initial_state = @current.dup
      yield.tap { @current = initial_state }
    end

    def load_state(object)
      klass_name = object.class.name.underscore.tr("/", "_")
      current.send(:"#{klass_name}=", object)
      collection_name = "#{klass_name.pluralize}_collection"
      return unless respond_to?(collection_name)

      send(collection_name) << object
    end
    alias_method :update_current, :load_state

    private

    # Override in subclasses for post-initialize hooks (e.g. pending phase rules).
    def setup
    end

    # Override in subclasses for post-block hooks (e.g. processing pending items).
    def teardown
    end

    def instantiate_blueprints
      self.class.blueprint_registry.each_key do |klass|
        ivar = :"@#{ivar_name_for(klass)}"
        instance_variable_set(ivar, klass.new(self))
      end

      # Set up delegation from foundry methods to blueprint instances
      self.class.delegations.each do |klass, methods|
        ivar = :"@#{ivar_name_for(klass)}"
        blueprint_instance = instance_variable_get(ivar)
        methods.each do |method_name|
          define_singleton_method(method_name) do |*args, **kwargs, &block|
            blueprint_instance.send(method_name, *args, **kwargs, &block)
          end
        end
      end
    end

    def initialize_collections
      self.class.collection_accessors.each do |col|
        instance_variable_set(:"@#{col}", Set.new)
        # Define accessor if not already defined
        define_singleton_method(col) { instance_variable_get(:"@#{col}") }
        define_singleton_method(:"#{col}=") { |val| instance_variable_set(:"@#{col}", val) }
      end
    end

    def ivar_name_for(klass)
      klass.name.demodulize.underscore
    end

    def find_blueprint_class_for(model_class_name)
      self.class.blueprint_registry.keys.detect do |klass|
        klass.name.demodulize.delete_suffix("Blueprint") == model_class_name
      end
    end
  end
end
