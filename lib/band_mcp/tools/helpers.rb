# frozen_string_literal: true

# rbs_inline: enabled

require "json"
require "mcp"
require "time"

require_relative "../client"

module BandMCP
  module Tools
    # Shared plumbing for tools that call BAND. Tool classes `extend` this so their `self.call` stays a one-liner and
    # every failure reaches the model as a tool error rather than crashing the server.
    module Helpers
      POST_FIELDS = %w[post_key band_key content comment_count emotion_count].freeze #: Array[String]

      # Yields a client and turns BandMCP::Error into an MCP error response.
      #: () { (Client) -> untyped } -> untyped
      def with_client
        yield Client.new
      rescue Error => e
        text_response(e.message, error: true)
      end

      #: (untyped data) -> untyped
      def json_response(data)
        text_response(JSON.generate(data))
      end

      #: (String text, ?error: bool) -> untyped
      def text_response(text, error: false)
        MCP::Tool::Response.new([{ type: "text", text: text }], error: error)
      end

      # Drops the photo/video payloads and author profile details, and turns BAND's epoch milliseconds into ISO 8601
      # so the model doesn't have to. Anything missing or oddly shaped is omitted rather than raised on.
      #: (Hash[String, untyped] post) -> Hash[String, untyped]
      def summarize_post(post)
        summary = post.slice(*POST_FIELDS)
        author = post["author"]
        summary["author"] = author["name"] if author.is_a?(Hash)
        created_at = post["created_at"]
        summary["created_at"] = Time.at(created_at / 1000, in: "UTC").iso8601 if created_at.is_a?(Integer)
        summary
      end
    end
  end
end
