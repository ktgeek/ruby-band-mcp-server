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
      COMMENT_FIELDS = %w[comment_key post_key content emotion_count].freeze #: Array[String]

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

      # `with_client` for a write. When the connection drops, that says nothing about whether the write took effect,
      # and a blind retry could repeat it, so the model is told to check first. `advice` says how.
      #: (String advice) { (Client) -> untyped } -> untyped
      def with_write_client(advice)
        with_client do |client|
          yield client
        rescue NetworkError => e
          text_response("#{e.message}. #{advice}", error: true)
        end
      end

      # For a response whose shape BAND changed. Reporting it as an error keeps it from reading as an empty or
      # all-denied answer.
      #: (String what) -> untyped
      def unexpected_format(what)
        text_response("BAND returned #{what} in an unexpected format", error: true)
      end

      #: (Hash[String, untyped] post) -> Hash[String, untyped]
      def summarize_post(post)
        summarize_record(post, POST_FIELDS)
      end

      #: (Hash[String, untyped] comment) -> Hash[String, untyped]
      def summarize_comment(comment)
        summarize_record(comment, COMMENT_FIELDS)
      end

      # Answers a BAND page of items as `{key => [...], "next_after" => cursor}`, yielding each item to summarize it.
      # A missing list means an empty page, but a list that isn't an array means BAND changed shape; saying "none"
      # there would mislead the model.
      #: (Hash[String, untyped] data, String key) { (Hash[String, untyped]) -> untyped } -> untyped
      def paged_response(data, key, &)
        items = data["items"]
        return unexpected_format(key) unless items.nil? || items.is_a?(Array)

        json_response({ key => Array(items).grep(Hash).map(&), "next_after" => next_after(data) })
      end

      # BAND's next_params also carries the access token, so only the cursor is passed on. Nothing else from it may
      # reach the model.
      #: (Hash[String, untyped] data) -> String?
      def next_after(data)
        paging = data["paging"]
        next_params = paging["next_params"] if paging.is_a?(Hash)
        after = next_params["after"] if next_params.is_a?(Hash)
        after if after.is_a?(String)
      end

      # Keeps the listed fields and drops the photo/video payloads and author profile details, and turns BAND's epoch
      # milliseconds into ISO 8601 so the model doesn't have to. Anything missing or oddly shaped is omitted rather
      # than raised on.
      #: (Hash[String, untyped] record, Array[String] fields) -> Hash[String, untyped]
      def summarize_record(record, fields)
        summary = record.slice(*fields)
        author = record["author"]
        summary["author"] = author["name"] if author.is_a?(Hash)
        created_at = record["created_at"]
        summary["created_at"] = Time.at(created_at / 1000, in: "UTC").iso8601 if created_at.is_a?(Integer)
        summary
      end
    end
  end
end
