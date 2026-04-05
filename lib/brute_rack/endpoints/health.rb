# frozen_string_literal: true

module BruteRack
  module Endpoints
    module Health
      def self.call(_env)
        [200, {"content-type" => "application/json"},
         [JSON.generate(status: "ok", version: Brute::VERSION)]]
      end
    end
  end
end
