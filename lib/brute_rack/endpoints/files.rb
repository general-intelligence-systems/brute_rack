# frozen_string_literal: true

require "open3"

module BruteRack
  module Endpoints
    # GET /find?pattern=pat         - search file contents (ripgrep)
    # GET /find/file?query=q        - find files by name
    # GET /file?path=path           - list directory
    # GET /file/content?path=p      - read file content
    # GET /file/status              → git status
    module Files
      def self.find(env, cwd:, **)
        params = parse_query(env)
        pattern = params["pattern"]
        return [400, HEADERS_JSON, [JSON.generate(error: "pattern required")]] unless pattern

        Brute::Tools::FSSearch.new.call(pattern: pattern, path: cwd).then do |result|
          matches = result[:results].to_s.lines.filter_map do |line|
            if line =~ /\A(.+?):(\d+):(.*)/
              { path: $1, line_number: $2.to_i, lines: $3.strip }
            end
          end
          [200, HEADERS_JSON, [JSON.generate(matches)]]
        end
      end

      def self.find_file(env, cwd:, **)
        params = parse_query(env)
        query = params["query"]
        return [400, HEADERS_JSON, [JSON.generate(error: "query required")]] unless query

        limit = (params["limit"] || 50).to_i.clamp(1, 200)
        type_filter = params["type"] # "file" or "directory"

        cmd = ["find", cwd, "-maxdepth", "8", "-iname", "*#{query}*"]
        cmd += ["-type", "f"] if type_filter == "file"
        cmd += ["-type", "d"] if type_filter == "directory"

        Open3.capture3(*cmd).then do |stdout, _, _|
          paths = stdout.lines.map(&:strip).reject(&:empty?).first(limit)
          [200, HEADERS_JSON, [JSON.generate(paths)]]
        end
      end

      def self.list(env, cwd:, **)
        params = parse_query(env)
        path = File.expand_path(params["path"] || ".", cwd)

        return [404, HEADERS_JSON, [JSON.generate(error: "not found")]] unless File.directory?(path)

        Dir.entries(path).reject { |f| f.start_with?(".") }.sort.map do |name|
          full = File.join(path, name)
          {
            name: name,
            path: full,
            type: File.directory?(full) ? "directory" : "file",
            size: File.file?(full) ? File.size(full) : nil,
          }
        end.then do |nodes|
          [200, HEADERS_JSON, [JSON.generate(nodes)]]
        end
      end

      def self.content(env, cwd:, **)
        params = parse_query(env)
        path = params["path"]
        return [400, HEADERS_JSON, [JSON.generate(error: "path required")]] unless path

        full = File.expand_path(path, cwd)
        return [404, HEADERS_JSON, [JSON.generate(error: "not found")]] unless File.exist?(full)
        return [400, HEADERS_JSON, [JSON.generate(error: "not a file")]] unless File.file?(full)

        {
          path: full,
          content: File.read(full, encoding: "UTF-8"),
          size: File.size(full),
          lines: File.readlines(full).size,
        }.then do |result|
          [200, HEADERS_JSON, [JSON.generate(result)]]
        end
      rescue Encoding::InvalidByteSequenceError
        [400, HEADERS_JSON, [JSON.generate(error: "binary file")]]
      end

      def self.status(_env, cwd:, **)
        Open3.capture3("git", "status", "--porcelain", chdir: cwd).then do |stdout, _, st|
          if st.success?
            files = stdout.lines.map { |l|
              { status: l[0..1].strip, path: l[3..].strip }
            }
            [200, HEADERS_JSON, [JSON.generate(files)]]
          else
            [200, HEADERS_JSON, [JSON.generate([])]]
          end
        end
      end

      def self.parse_query(env)
        Rack::Utils.parse_query(env["QUERY_STRING"] || "")
      end
    end
  end
end
