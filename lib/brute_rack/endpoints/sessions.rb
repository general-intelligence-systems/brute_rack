# frozen_string_literal: true

module BruteRack
  module Endpoints
    # GET    /sessions     — list saved sessions
    # DELETE /sessions/:id — delete a session
    #
    module Sessions
      def self.list(_env)
        Brute::Session.list.then do |sessions|
          [200, {"content-type" => "application/json"}, [JSON.generate(sessions)]]
        end
      end

      def self.delete(_env, id:)
        Brute::Session.new(id: id).delete
        [200, {"content-type" => "application/json"},
         [JSON.generate(deleted: true, id: id)]]
      rescue => e
        [500, {"content-type" => "application/json"},
         [JSON.generate(error: e.message)]]
      end
    end
  end
end
