# frozen_string_literal: true

# rbs_inline: enabled

require "mcp"

require_relative "helpers"

module BandMCP
  module Tools
    class CreatePost < MCP::Tool
      extend Helpers

      # A blind retry would duplicate the post for every member.
      UNCERTAIN_OUTCOME = "The post may still have been published; check the band before retrying." #: String

      tool_name "create_post"
      description "Publish a text post to a BAND as the user. Visible to the band's members, so confirm the band " \
                  "and wording with the user first. Returns the post_key; pass it to get_post to confirm the post " \
                  "landed. Find band_key with list_bands. Members are only push-notified if do_push is true."
      input_schema(
        properties: {
          band_key: { type: "string", minLength: 1, description: "Band to post to, from list_bands." },
          content: { type: "string", pattern: "\\S", description: "Body of the post. Must not be blank." },
          do_push: { type: "boolean", description: "Push-notify subscribed members. Defaults to false." }
        },
        required: %w[band_key content]
      )
      annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: false)

      #: (band_key: String, content: String, ?do_push: bool, **untyped) -> untyped
      def self.call(band_key:, content:, do_push: false, **)
        with_write_client(UNCERTAIN_OUTCOME) do |client|
          data = client.post(
            "/v2.2/band/post/create",
            { "band_key" => band_key, "content" => content, "do_push" => do_push }
          )
          json_response(data.slice("band_key", "post_key"))
        end
      end
    end
  end
end
