# frozen_string_literal: true

# rbs_inline: enabled

require "mcp"

require_relative "helpers"

module BandMCP
  module Tools
    class CheckPermissions < MCP::Tool
      extend Helpers

      PERMISSIONS = %w[posting commenting contents_deletion].freeze #: Array[String]

      tool_name "check_permissions"
      description "Check what the user is allowed to do in a BAND before trying it: posting (create_post), " \
                  "commenting, and contents_deletion (removing posts and comments). Band settings can deny these " \
                  "even to members. Returns the granted and denied permissions. contents_deletion says nothing " \
                  "about authorship, so removing someone else's post can still fail. Find band_key with list_bands."
      input_schema(
        properties: {
          band_key: { type: "string", minLength: 1, description: "Band to check, from list_bands." },
          permissions: {
            type: "array", minItems: 1, uniqueItems: true, items: { type: "string", enum: PERMISSIONS },
            description: "Permissions to check."
          }
        },
        required: %w[band_key permissions]
      )
      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true)

      #: (band_key: String, permissions: Array[String], **untyped) -> untyped
      def self.call(band_key:, permissions:, **)
        with_client do |client|
          data = client.get("/v2/band/permissions", { "band_key" => band_key, "permissions" => permissions.join(",") })
          granted = granted_permissions(data)
          if granted
            json_response({ "granted" => permissions & granted, "denied" => permissions - granted })
          else
            unexpected_format("permissions")
          end
        end
      end

      # BAND's docs name the result key `permissions` in the field table but `permission` in the example, so both are
      # accepted. Returns nil when neither holds a list, so a changed format isn't reported as everything denied.
      #: (Hash[String, untyped] data) -> Array[String]?
      def self.granted_permissions(data)
        granted = data["permissions"] || data["permission"]
        granted if granted.is_a?(Array)
      end
    end
  end
end
