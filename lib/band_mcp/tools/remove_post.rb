# frozen_string_literal: true

# rbs_inline: enabled

require "mcp"

require_relative "helpers"

module BandMCP
  module Tools
    class RemovePost < MCP::Tool
      extend Helpers

      UNCERTAIN_OUTCOME = "The post may already have been removed. Check with get_post before retrying: BAND " \
                          "reporting it as deleted or not found means the removal worked." #: String

      tool_name "remove_post"
      description "Permanently delete a post from a BAND. It disappears for every member and cannot be undone, so " \
                  "confirm the band and post with the user first, e.g. by showing them get_post's result. " \
                  "Check contents_deletion with check_permissions beforehand; that permission does not cover " \
                  "authorship, so removing someone else's post can still fail. Find band_key with list_bands and " \
                  "post_key with list_posts. BAND can answer 'Cool down time restriction' (1003) right after another " \
                  "write; wait a minute and retry."
      input_schema(
        properties: {
          band_key: { type: "string", minLength: 1, description: "Band the post belongs to, from list_bands." },
          post_key: { type: "string", minLength: 1, description: "Post to delete, from list_posts or create_post." }
        },
        required: %w[band_key post_key]
      )
      annotations(read_only_hint: false, destructive_hint: true, idempotent_hint: true)

      #: (band_key: String, post_key: String, **untyped) -> untyped
      def self.call(band_key:, post_key:, **)
        with_write_client(UNCERTAIN_OUTCOME) do |client|
          client.post("/v2/band/post/remove", { "band_key" => band_key, "post_key" => post_key })
          json_response({ "band_key" => band_key, "post_key" => post_key, "removed" => true })
        end
      end
    end
  end
end
