# frozen_string_literal: true

# rbs_inline: enabled

require "mcp"

require_relative "helpers"

module BandMCP
  module Tools
    class ListComments < MCP::Tool
      extend Helpers

      NEWEST_FIRST_SORT = "-created_at" #: String

      # BAND's cursor only works with the sort it came from; paired with the wrong one it silently skips and repeats
      # comments. So next_after carries the order as a tag, and a cursor without one is refused.
      ORDER_TAGS = { false => "oldest", true => "newest" }.freeze #: Hash[bool, String]
      TAGGED_CURSOR = /\A(?<tag>#{ORDER_TAGS.values.join('|')}):(?<cursor>.+)\z/m #: Regexp

      BAD_CURSOR = "after must be a next_after value from a previous list_comments result, passed back unchanged " \
                   "(it starts with oldest: or newest:). Leave after out to start from the first page." #: String

      tool_name "list_comments"
      description "List the comments on a post in a BAND, oldest first unless newest_first is true, with each " \
                  "comment's comment_key, text, author, time and emotion count. BAND chooses the page size (20 when " \
                  "tested). If next_after in the result is not null, there are more comments: pass it unchanged as " \
                  "`after` to get the next page; it remembers the order, so newest_first only matters for the " \
                  "first page. Find band_key with " \
                  "list_bands and post_key with list_posts."
      input_schema(
        properties: {
          band_key: { type: "string", minLength: 1, description: "Band the post belongs to, from list_bands." },
          post_key: { type: "string", minLength: 1, description: "Post whose comments to read, from list_posts." },
          after: { type: "string", minLength: 1,
                   description: "The next_after value from a previous result, unchanged." },
          newest_first: { type: "boolean",
                          description: "List the newest comments first. Defaults to false. Ignored when `after` " \
                                       "is given." }
        },
        required: %w[band_key post_key]
      )
      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true)

      #: (band_key: String, post_key: String, ?after: String?, ?newest_first: bool, **untyped) -> untyped
      def self.call(band_key:, post_key:, after: nil, newest_first: false, **)
        if after
          newest_first, cursor = parse_cursor(after)
          return text_response(BAD_CURSOR, error: true) unless cursor
        end
        with_client do |client|
          sort = NEWEST_FIRST_SORT if newest_first
          params = { "band_key" => band_key, "post_key" => post_key, "after" => cursor, "sort" => sort }.compact
          data = client.get("/v2/band/post/comments", params)
          paged_response(data, "comments", prefix: "#{ORDER_TAGS[newest_first]}:") { |item| summarize_comment(item) }
        end
      end

      # The order and BAND's cursor out of a next_after value, or nil for the cursor when it isn't one of ours.
      #: (String after) -> [bool, String?]
      def self.parse_cursor(after)
        match = TAGGED_CURSOR.match(after)
        return [false, nil] unless match

        [ORDER_TAGS.key(match[:tag]) || false, match[:cursor]]
      end
    end
  end
end
