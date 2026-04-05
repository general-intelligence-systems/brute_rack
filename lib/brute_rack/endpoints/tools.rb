# frozen_string_literal: true

module BruteRack
  module Endpoints
    # GET /experimental/tool/ids              → list tool names
    # GET /experimental/tool?provider=&model= → list tools with schemas
    module Tools
      def self.ids(_env, **)
        names = LLM::Function.registry.map(&:name)
        [200, HEADERS_JSON, [JSON.generate(names)]]
      end

      def self.list(_env, **)
        tools = LLM::Function.registry.map do |fn|
          schema = if fn.params
            { type: "object", properties: serialize_params(fn.params) }
          else
            { type: "object", properties: {} }
          end

          {
            name: fn.name,
            description: fn.description,
            input_schema: schema,
          }
        end
        [200, HEADERS_JSON, [JSON.generate(tools)]]
      end

      def self.serialize_params(params)
        return {} unless params.respond_to?(:properties)
        params.properties.transform_values do |prop|
          {
            type: prop.class.name.split("::").last.downcase,
            description: prop.respond_to?(:description) ? prop.description : nil,
            required: prop.respond_to?(:required) ? prop.required : nil,
          }.compact
        end
      rescue
        {}
      end
    end
  end
end
