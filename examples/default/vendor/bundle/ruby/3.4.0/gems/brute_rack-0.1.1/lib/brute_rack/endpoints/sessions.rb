# frozen_string_literal: true

module BruteRack
  module Endpoints
    # GET    /session           → list sessions
    # POST   /session           → create session { parentID?, title? }
    # GET    /session/status    → { session_id: status, ... }
    # GET    /session/:id       → session details
    # PATCH  /session/:id       → update title { title }
    # DELETE /session/:id       → delete session
    # POST   /session/:id/abort → abort running session
    # POST   /session/:id/fork  → fork session { messageID? }
    # POST   /session/:id/summarize → compact session { providerID, modelID }
    # GET    /session/:id/todo  → todo list
    module Sessions
      def self.list(_env, **)
        Brute::Session.list.then do |sessions|
          [200, HEADERS_JSON, [JSON.generate(sessions)]]
        end
      end

      def self.create(env, registry:, **)
        parse_body(env).then do |body|
          id = SecureRandom.uuid
          # Don't eagerly create orchestrator — that requires an API key.
          # The orchestrator is created lazily when a message is sent.
          Brute::Session.new(id: id)
          [200, HEADERS_JSON, [JSON.generate(id: id, title: body["title"])]]
        end
      end

      def self.status(_env, registry:, **)
        [200, HEADERS_JSON, [JSON.generate(registry.all_statuses)]]
      end

      def self.get(_env, id:, **)
        Brute::Session.list.then do |sessions|
          sessions.find { |s| s[:id] == id }.then do |found|
            if found
              [200, HEADERS_JSON, [JSON.generate(found)]]
            else
              [404, HEADERS_JSON, [JSON.generate(error: "session not found")]]
            end
          end
        end
      end

      def self.update(env, id:, **)
        parse_body(env).then do |body|
          # We store title in the metadata sidecar
          meta_dir = File.join(Dir.home, ".forge", "sessions")
          meta_path = File.join(meta_dir, "#{id}.meta.json")
          if File.exist?(meta_path)
            JSON.parse(File.read(meta_path)).then do |meta|
              meta["title"] = body["title"] if body["title"]
              File.write(meta_path, JSON.generate(meta))
              [200, HEADERS_JSON, [JSON.generate(meta)]]
            end
          else
            [404, HEADERS_JSON, [JSON.generate(error: "session not found")]]
          end
        end
      end

      def self.delete(_env, id:, registry:, **)
        registry.remove(id)
        Brute::Session.new(id: id).delete
        [200, HEADERS_JSON, [JSON.generate(true)]]
      end

      def self.abort(_env, id:, registry:, **)
        registry.abort(id)
        [200, HEADERS_JSON, [JSON.generate(true)]]
      end

      def self.fork(env, id:, registry:, **)
        parse_body(env).then do |body|
          new_id = SecureRandom.uuid
          # Create a new session, optionally copying from source
          registry.get_or_create(new_id)
          source_session = registry.session(id)
          if source_session && File.exist?(source_session.path)
            new_session = registry.session(new_id)
            FileUtils.cp(source_session.path, new_session.path)
            meta_src = source_session.path.sub(/\.json$/, ".meta.json")
            if File.exist?(meta_src)
              meta_dst = new_session.path.sub(/\.json$/, ".meta.json")
              FileUtils.cp(meta_src, meta_dst)
            end
          end
          [200, HEADERS_JSON, [JSON.generate(id: new_id, forked_from: id)]]
        end
      end

      def self.summarize(env, id:, registry:, **)
        orch = registry.get(id)
        return [404, HEADERS_JSON, [JSON.generate(error: "session not found")]] unless orch

        compactor = Brute::Compactor.new(Brute.provider)
        messages = orch.context.messages.to_a.compact
        compactor.compact(messages).then do |result|
          if result
            [200, HEADERS_JSON, [JSON.generate(true)]]
          else
            [200, HEADERS_JSON, [JSON.generate(false)]]
          end
        end
      end

      def self.todo(_env, id:, **)
        [200, HEADERS_JSON, [JSON.generate(Brute::TodoStore.all)]]
      end

      def self.parse_body(env)
        input = env["rack.input"].read
        input.empty? ? {} : JSON.parse(input)
      end
    end
  end
end
