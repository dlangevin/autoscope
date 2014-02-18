module Autoscope
  module ActiveRecordMethods

    extend ActiveSupport::Concern

    included do |klass|

      klass.class_attribute :scope_definition
      klass.scope_definition = {}

      # add scope protection behavior
      class << klass
        alias_method_chain :scope, :resource_definition_addition
      end

    end

    module ClassMethods

      # adds any available scopes to the scope
      # passed in
      #
      # @example
      #   class MyController < ActionController::Base
      #     # GET /my_resources.json
      #     def index
      #       @my_resources = MyResource.add_scopes(params)
      #     end
      #   end
      #
      # @param params [Hash]
      # @param scope [ActiveRecord::Relation]
      # @return [ActiveRecord::Relation]

      def add_scopes(params, scope = self.all)
        params = params.with_indifferent_access

        # add any type parameters
        scope = self.add_type_filter(params, scope)
        # add our static scopes
        scope = self.add_static_scopes(params, scope)
        scope = self.add_dynamic_scopes(params, scope)
        scope = self.add_pagination(params, scope)
        scope
      end

      protected

      # adds scopes that don't take any parameters to the scope
      # passed in
      #
      # @example
      #   class MyController < ActionController::Base
      #     # GET /my_resources.json
      #     def index
      #       @my_resources = MyResource.add_static_scopes(params)
      #     end
      #   end
      #
      # @param params [Hash]
      # @param scope [ActiveRecord::Relation]
      # @return [ActiveRecord::Relation]
      def add_static_scopes(params, scope = self.all)
        scope.klass.static_scopes.each do |scope_name|
          if params[scope_name].present?
            scope = scope.send(scope_name)
          end
        end
        # special case for ids
        if params[:ids].present?
          scope = scope.where(id: params[:ids])
        end
        scope
      end

      def add_type_filter(params, scope)
        return scope unless params[:type].present?

        # get the class - rescuing an invalid class name
        begin
          klass = params[:type].constantize

          # if we have been given a class that is not a subclass
          # we should return the original scope

          unless self.descendants.include?(klass)
            logger.error("#{klass} is not a descendant of #{self}")
            return scope
          end

          # merge in our old scope and return
          klass.all.merge(scope)
        rescue NameError => e
          logger.error(e.message)
          logger.error(e.backtrace.pretty_inspect)
          return scope
        end
      end

      # adds scopes that take parameters to the scope
      # passed in
      #
      # @param params [Hash]
      # @param scope [ActiveRecord::Relation]
      # @return [ActiveRecord::Relation]
      #
      # @example
      #   class MyController < ActionController::Base
      #     # GET /my_resources.json
      #     def index
      #       @my_resources = MyResource.add_static_scopes(params)
      #     end
      #   end
      def add_dynamic_scopes(params, scope = self.all)
        scope.klass.dynamic_scopes.each_pair do |scope_name, arg_def|

          # skip scopes that are not defined
          next if params[scope_name].blank?

          # now apply the arguments
          args_to_pass = []

          # arg def tells us which args are required
          arg_def.each_pair do |arg_name, arg_type|
            case arg_type.to_sym
            # this argument is required
            when :req
              args_to_pass << params[scope_name][arg_name]
            when :opt
              unless params[scope_name][arg_name].nil?
                args_to_pass << params[scope_name][arg_name]
              end
            when :rest
              args_to_pass.concat(params[scope_name][arg_name] || [])
            end
          end

          # actually apply the scope
          scope = scope.send(scope_name, *args_to_pass)
        end

        # return the final scope
        scope
      end

      #
      # Add pagination if it is supplied in the params
      #
      # @param  params [Hash]
      # @param  scope = self.all [ActiveRecord::Relation]
      #
      # @return [ActiveRecord::Relation]
      def add_pagination(params, scope = self.all)
        if params[:page] || params[:per_page]
          scope = scope.paginate(
            page: params[:page] || 1,
            per_page: params[:per_page] || 20
          )
        end
        return scope
      end

      #
      # Helper to extract scope options into something usable in a
      # resource definition
      #
      # @param  proc [Proc] Scope proc
      #
      # @return [Hash<Symbol,Symbol>]
      def get_scope_parameters(proc)
        params = {}
        proc.parameters.each do |type, param|
          params[param] = type
        end
        params
      end

      #
      # Set up a regular scope, but mark it as protected
      # (not visible via the api)
      #
      # @param [Array<Mixed>] Args to create a scope
      #
      # @return [Class] self
      def protected_scope(*args)
        self.scope_without_resource_definition_addition(*args)
      end

      #
      # set up a regular scope, making it visibule to the API
      #
      def scope_with_resource_definition_addition(name, scope_options = {}, &block)
        # if it's a proc, we figure out its parameters
        params = if scope_options.is_a?(Proc)
          self.get_scope_parameters(scope_options)
        # otherwise we just use a blank hash
        else
          {}
        end

        # update scope definition
        self.scope_definition.merge!(
          name.to_sym => params
        )

        # call the original scope definition method
        self.scope_without_resource_definition_addition(
          name,
          scope_options,
          &block
        )
      end

      #
      # list of all scopes that take an argument
      #
      # @return [Hash<Symbol, Hash>]
      def dynamic_scopes
        scopes = self.scope_definition.select { |k, v| v.present? }
      end

      #
      # list of all scopes that don't take any arguments
      #
      # @return [Array<Hash>]
      def static_scopes
        scopes = self.scope_definition
          .select { |k, v| v.blank? }
          .keys
        scopes | [:first, :last, :all]
      end

    end

  end
end