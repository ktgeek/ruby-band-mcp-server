# frozen_string_literal: true

# rbs_inline: enabled

require "mcp"

require_relative "helpers"

module BandMCP
  module Tools
    class CreateComment < MCP::Tool
      extend Helpers

      # A blind retry would add a duplicate comment for every member to see.
      UNCERTAIN_OUTCOME = "The comment may still have been added; check with list_comments before retrying." #: String

      tool_name "create_comment"
      description "Add a comment to a post in a BAND as the user. Visible to the band's members, so confirm the " \
                  "post and wording with the user first. BAND does not return the new comment's key; call " \
                  "list_comments to find it. Check the commenting permission with check_permissions if unsure. " \
                  "Find band_key with list_bands and post_key with list_posts. BAND can answer 'Cool down time " \
                  "restriction' (1003) when comments come in quick succession; leave about ten seconds between " \
                  "comments, or wait that long and retry."
      input_schema(
        properties: {
          band_key: { type: "string", minLength: 1, description: "Band the post belongs to, from list_bands." },
          post_key: { type: "string", minLength: 1, description: "Post to comment on, from list_posts." },
          content: { type: "string", pattern: "\\S", description: "Text of the comment. Must not be blank." }
        },
        required: %w[band_key post_key content]
      )
      annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: false)

      #: (band_key: String, post_key: String, content: String, **untyped) -> untyped
      def self.call(band_key:, post_key:, content:, **)
        with_write_client(UNCERTAIN_OUTCOME) do |client|
          client.post("/v2/band/post/comment/create",
                      { "band_key" => band_key, "post_key" => post_key, "body" => content })
          json_response({ "band_key" => band_key, "post_key" => post_key, "created" => true })
        end
      end
    end
  end
end
