# frozen_string_literal: true

# rbs_inline: enabled

require "mcp"
require "time"

require_relative "helpers"

module BandMCP
  module Tools
    class GetPost < MCP::Tool
      extend Helpers

      PASSTHROUGH_FIELDS = %w[post_key band_key content comment_count emotion_count].freeze #: Array[String]

      tool_name "get_post"
      description "Fetch one post from a BAND by band_key and post_key, e.g. to confirm that a post made with " \
                  "create_post was published. Returns the text, author, creation time and comment/emotion counts."
      input_schema(
        properties: {
          band_key: { type: "string", minLength: 1, description: "Band the post belongs to, from list_bands." },
          post_key: { type: "string", minLength: 1, description: "Post to fetch, e.g. from create_post." }
        },
        required: %w[band_key post_key]
      )
      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true)

      #: (band_key: String, post_key: String, **untyped) -> untyped
      def self.call(band_key:, post_key:, **)
        with_client do |client|
          data = client.get("/v2.1/band/post", { "band_key" => band_key, "post_key" => post_key })
          post = data["post"]
          if post.is_a?(Hash)
            json_response(summarize(post))
          else
            text_response("BAND returned no post for that band_key and post_key", error: true)
          end
        end
      end

      # Drops the photo/video payloads and author profile details, and turns BAND's epoch milliseconds into ISO 8601
      # so the model doesn't have to.
      #: (Hash[String, untyped] post) -> Hash[String, untyped]
      def self.summarize(post)
        summary = post.slice(*PASSTHROUGH_FIELDS)
        summary["author"] = post.dig("author", "name")
        summary["created_at"] = Time.at(post["created_at"] / 1000, in: "UTC").iso8601 if post["created_at"]
        summary
      end
    end
  end
end
