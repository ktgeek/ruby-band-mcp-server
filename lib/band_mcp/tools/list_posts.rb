# frozen_string_literal: true

# rbs_inline: enabled

require "mcp"

require_relative "helpers"

module BandMCP
  module Tools
    class ListPosts < MCP::Tool
      extend Helpers

      DEFAULT_LOCALE = "en_US" #: String

      tool_name "list_posts"
      description "List recent posts in a BAND, most recently modified first, with each post's text, author, time " \
                  "and comment/emotion counts. BAND chooses the page size. If next_after in the result is not " \
                  "null, pass it as `after` to get the next page. Find band_key with list_bands."
      input_schema(
        properties: {
          band_key: { type: "string", minLength: 1, description: "Band to read, from list_bands." },
          after: { type: "string", description: "The next_after value from a previous result." },
          locale: { type: "string", description: "Region and language for BAND's response. Defaults to en_US." }
        },
        required: %w[band_key]
      )
      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true)

      #: (band_key: String, ?after: String?, ?locale: String, **untyped) -> untyped
      def self.call(band_key:, after: nil, locale: DEFAULT_LOCALE, **)
        with_client do |client|
          params = { "band_key" => band_key, "locale" => locale, "after" => after }.compact
          data = client.get("/v2/band/posts", params)
          # Array() turns a missing list into [], and grep(Hash) skips anything that is not a post object.
          posts = Array(data["items"]).grep(Hash).map { |item| summarize_post(item) }
          json_response({ "posts" => posts, "next_after" => next_after(data) })
        end
      end

      # BAND's next_params also carries the access token, so only the cursor is passed on. Nothing else from it may
      # reach the model.
      #: (Hash[String, untyped] data) -> String?
      def self.next_after(data)
        paging = data["paging"]
        next_params = paging["next_params"] if paging.is_a?(Hash)
        after = next_params["after"] if next_params.is_a?(Hash)
        after if after.is_a?(String)
      end
    end
  end
end
