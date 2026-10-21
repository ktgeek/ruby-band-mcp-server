# frozen_string_literal: true

# rbs_inline: enabled

require "mcp"

require_relative "helpers"

module BandMCP
  module Tools
    class ListComments < MCP::Tool
      extend Helpers

      NEWEST_FIRST_SORT = "-created_at" #: String

      tool_name "list_comments"
      description "List the comments on a post in a BAND, oldest first unless newest_first is true, with each " \
                  "comment's comment_key, text, author, time and emotion count. BAND chooses the page size. If " \
                  "next_after in the result is not null, pass it as `after` (with the same newest_first) to get " \
                  "the next page. Find band_key with list_bands and post_key with list_posts."
      input_schema(
        properties: {
          band_key: { type: "string", minLength: 1, description: "Band the post belongs to, from list_bands." },
          post_key: { type: "string", minLength: 1, description: "Post whose comments to read, from list_posts." },
          after: { type: "string", minLength: 1, description: "The next_after value from a previous result." },
          newest_first: { type: "boolean", description: "List the newest comments first. Defaults to false." }
        },
        required: %w[band_key post_key]
      )
      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true)

      #: (band_key: String, post_key: String, ?after: String?, ?newest_first: bool, **untyped) -> untyped
      def self.call(band_key:, post_key:, after: nil, newest_first: false, **)
        with_client do |client|
          sort = NEWEST_FIRST_SORT if newest_first
          params = { "band_key" => band_key, "post_key" => post_key, "after" => after, "sort" => sort }.compact
          data = client.get("/v2/band/post/comments", params)
          paged_response(data, "comments") { |item| summarize_comment(item) }
        end
      end
    end
  end
end
