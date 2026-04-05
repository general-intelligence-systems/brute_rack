# frozen_string_literal: true

require "open3"

module BruteRack
  module Endpoints
    # GET /path → { cwd: "..." }
    # GET /vcs  → { branch, remote, dirty, ... }
    module PathVcs
      def self.path(_env, cwd:, **)
        [200, HEADERS_JSON, [JSON.generate(cwd: cwd)]]
      end

      def self.vcs(_env, cwd:, **)
        branch, _ = Open3.capture2("git", "rev-parse", "--abbrev-ref", "HEAD", chdir: cwd)
        remote, _ = Open3.capture2("git", "remote", "get-url", "origin", chdir: cwd)
        status, _ = Open3.capture2("git", "status", "--porcelain", chdir: cwd)
        sha, _    = Open3.capture2("git", "rev-parse", "--short", "HEAD", chdir: cwd)

        {
          branch: branch.strip,
          remote: remote.strip,
          sha: sha.strip,
          dirty: !status.strip.empty?,
          changed_files: status.lines.size,
        }.then { |info| [200, HEADERS_JSON, [JSON.generate(info)]] }
      rescue => e
        [200, HEADERS_JSON, [JSON.generate(error: "not a git repository", message: e.message)]]
      end
    end
  end
end
