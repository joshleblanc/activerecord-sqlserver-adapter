# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module SQLServer
      module CoreExt
        module ArrayHandler
          module NullPredicate # :nodoc:
            def self.or(other)
              other
            end
          end

          def call(attribute, value)
            return attribute.in([]) if value.empty?

            values = value.map { |x| x.is_a?(Base) ? x.id : x }
            nils = values.extract!(&:nil?)
            ranges = values.extract! { |v| v.is_a?(Range) }

            values_predicate =
              case values.length
              when 0 then NullPredicate
              when 1 then predicate_builder.build(attribute, values.first)
              else
                values.map! do |v|
                  predicate_builder.build_bind_attribute(attribute.name, v)
                end
                values.empty? ? NullPredicate : attribute.in(values)
              end

            unless nils.empty?
              values_predicate = values_predicate.or(predicate_builder.build(attribute, nil))
            end

            array_predicates = ranges.map { |range| predicate_builder.build(attribute, range) }
            array_predicates.unshift(values_predicate)
            array_predicates.inject(&:or)
          end
        end
      end
    end
  end
end

ActiveSupport.on_load(:active_record) do
  mod = ActiveRecord::ConnectionAdapters::SQLServer::CoreExt::ArrayHandler
  ActiveRecord::PredicateBuilder::ArrayHandler.prepend(mod)
end
