# frozen_string_literal: true

# rbs_inline: enabled

require "mcp"

require_relative "helpers"

module BandMCP
  module Tools
    class RemoveComment < MCP::Tool
      extend Helpers

      UNCERTAIN_OUTCOME = "The comment may already have been removed. Check with list_comments before retrying, " \
                          "paging through with `after` if the post has many comments: if its comment_key is " \
                          "gone, the removal worked." #: String

      tool_name "remove_comment"
      description "Permanently delete a comment from a post in a BAND. It disappears for every member and cannot " \
                  "be undone, so confirm the comment with the user first, e.g. by showing them list_comments' " \
                  "result. BAND's docs say only comments made through this app can be removed, and " \
                  "contents_deletion (check_permissions) does not cover authorship, so removing someone else's " \
                  "comment can still fail. comment_key is only meaningful together with its post_key; find it " \
                  "with list_comments. BAND can answer 'Cool down time restriction' (1003) right after another " \
                  "write; wait a minute and retry."
      input_schema(
        properties: {
          band_key: { type: "string", minLength: 1, description: "Band the post belongs to, from list_bands." },
          post_key: { type: "string", minLength: 1, description: "Post the comment is on, from list_posts." },
          comment_key: { type: "string", minLength: 1, description: "Comment to delete, from list_comments." }
        },
        required: %w[band_key post_key comment_key]
      )
      annotations(read_only_hint: false, destructive_hint: true, idempotent_hint: true)

      #: (band_key: String, post_key: String, comment_key: String, **untyped) -> untyped
      def self.call(band_key:, post_key:, comment_key:, **)
        with_write_client(UNCERTAIN_OUTCOME) do |client|
          keys = { "band_key" => band_key, "post_key" => post_key, "comment_key" => comment_key }
          client.post("/v2/band/post/comment/remove", keys)
          json_response(keys.merge("removed" => true))
        end
      end
    end
  end
end
