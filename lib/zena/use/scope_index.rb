module Zena
  module Use
    module ScopeIndex
      AVAILABLE_MODELS = []

      def self.models_for_form
        [''] + AVAILABLE_MODELS.map(&:to_s)
      end

      module VirtualClassMethods
        def self.included(base)
          base.validate :validate_idx_class, :validate_idx_scope
          base.attr_accessible :idx_class
          base.attr_accessible :idx_scope
        end

        protected
          def validate_idx_class
            self[:idx_class] = nil if self[:idx_class].blank?

            if model_name = self[:idx_class]
              if model_name =~ /\A[A-Z][a-zA-Z]+\Z/
                if klass = Zena.const_get(model_name) rescue NilClass
                  if klass < Zena::Use::ScopeIndex::IndexMethods
                    # ok
                  else
                    errors.add('idx_class', 'invalid class (should include ScopeIndex::IndexMethods)')
                  end
                else
                  errors.add('idx_class', 'invalid class')
                end
              else
                errors.add('idx_class', 'invalid class name')
              end
            end
          end

          def validate_idx_scope
            self[:idx_scope] = nil if self[:idx_scope].blank?

            if pseudo_sql = self[:idx_scope]
              # Try to compile query in instance of class self
              begin
                klass = Zena::Acts::Enrollable.make_class(self)
                query = real_class.build_query(:all, pseudo_sql,
                  :node_name       => 'self',
                  :main_class      => klass,
                  :rubyless_helper => klass
                )
              rescue ::QueryBuilder::Error => err
                errors.add('idx_scope', "Invalid query: #{err.message}")
              end
            end
          end
      end # VirtualClassMethods

      module IndexClassMethods
        # Return the column groups for which the node with the given kpath should
        # be used alter index values.
        def match_groups(kpath)
          groups.keys.select {|key| kpath =~ %r{\A#{key}}}
        end
      end # ClassMethods

      module IndexMethods
        def self.included(base)
          AVAILABLE_MODELS << base

          class << base
            attr_accessor :groups
          end

          base.class_eval do
            include RubyLess
            extend IndexClassMethods
            before_validation     :set_site_id
            validates_presence_of :node_id
          end

          groups = base.groups = {}
          base.column_names.each do |name|
            next if %{created_at updated_at id node_id}.include?(name)
            if name =~ %r{\A([A-Z]+)_(.+)\Z}
              (groups[$1] ||= []) << $2
              unless $2 == 'id'
                base.safe_attribute name
              end
            end
          end
        end

        # The given node has been updated in the owner's project. Update index
        # entries with this node's content if necessary.
        def update_with(node, force_create = false)
          attrs = {}
          self.class.match_groups(node.kpath).each do |group_key|
            next unless should_update_group?(group_key, node)
            self.class.groups[group_key].each do |key|
              attrs["#{group_key}_#{key}"] = node.send(key)
            end
          end

          if !attrs.empty? || force_create
            self.attributes = attrs
            save
          end
        end

        # Return true if the indices from the given group should be altered by the node.
        def should_update_group?(group_key, node)
          node.id >= self["#{group_key}_id"].to_i
        end

        def set_site_id
          self[:site_id] = current_site.id
        end
      end # ModelMethods

      module ModelMethods
        def self.included(base)
          base.after_save :update_scope_indices
          base.safe_context :scope_index => scope_index_proc
        end

        def self.scope_index_proc
          Proc.new do |helper, signature|
            vclass = helper.klass
            if vclass && vclass.idx_class && klass = Zena.resolve_const(vclass.idx_class) rescue nil
              {:method => 'scope_index', :nil => true, :class => klass}
            else
              raise RubyLess::NoMethodError.new(helper, helper, signature)
            end
          end
        end

        # Access the index model inside the Project or Section.
        def scope_index
          @scope_index ||= begin
            vclass = virtual_class
            if vclass && klass = vclass.idx_class
              if klass = Zena.resolve_const(klass) rescue nil
                klass.find(:first, :conditions => {:node_id => self.id, :site_id => current_site.id}) || klass.new(:node_id => self.id)
              else
                nil
              end
            else
              nil
            end
          end
        end

        protected
          # Update scope indices (project/section).
          def update_scope_indices
            return unless version.status == Zena::Status[:pub]
            if virtual_class && query = virtual_class.idx_scope
              if query.strip == 'self'
                models_to_update = [self]
              else
                models_to_update = find(:all, query)
              end

              models_to_update.each do |m|
                if idx_model = m.scope_index
                  # force creation of index record
                  idx_model.update_with(self, true)
                end
              end
            end
          # rescue QueryBuilder::Error
            # ignore
          end
      end # ModelMethods
    end # ScopeIndex
  end # Acts
end # Zena