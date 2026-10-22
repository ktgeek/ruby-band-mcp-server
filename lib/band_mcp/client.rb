# frozen_string_literal: true

# rbs_inline: enabled

require "json"
require "net/http"
require "uri"

require_relative "config"
require_relative "error"

module BandMCP
  # Minimal BAND Open API client. Callers pass the full versioned path (`/v2.1/bands`) because BAND versions each
  # endpoint separately. Both verbs return the response's `result_data` and raise BandMCP::Error on any failure.
  class Client
    BASE_URL = "https://openapi.band.us" #: String
    SUCCESS_CODE = 1 #: Integer
    OPEN_TIMEOUT = 10 #: Integer
    READ_TIMEOUT = 30 #: Integer
    NETWORK_ERRORS = [
      SocketError, SystemCallError, IOError, EOFError, Timeout::Error, OpenSSL::SSL::SSLError,
      Net::ProtocolError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError
    ].freeze #: Array[Class]

    # @rbs @access_token: String

    #: (?access_token: String?) -> void
    def initialize(access_token: Config.access_token)
      raise Error, "BAND_ACCESS_TOKEN is not set" if access_token.nil?

      @access_token = access_token
    end

    #: (String path, ?Hash[String, untyped] params) -> Hash[String, untyped]
    def get(path, params = {})
      uri = uri_for(path)
      uri.query = URI.encode_www_form(params) unless params.empty?
      perform(uri, Net::HTTP::Get.new(uri))
    end

    #: (String path, ?Hash[String, untyped] params) -> Hash[String, untyped]
    def post(path, params = {})
      uri = uri_for(path)
      request = Net::HTTP::Post.new(uri)
      request.set_form_data(params)
      perform(uri, request)
    end

    private

    #: (String path) -> URI::Generic
    def uri_for(path)
      URI("#{BASE_URL}#{path}")
    end

    #: (URI::Generic uri, Net::HTTPRequest request) -> Hash[String, untyped]
    def perform(uri, request)
      request["Authorization"] = "Bearer #{@access_token}"
      response = Net::HTTP.start(uri.hostname.to_s, uri.port, use_ssl: true, open_timeout: OPEN_TIMEOUT,
                                                              read_timeout: READ_TIMEOUT) do |http|
        http.request(request)
      end
      parse(response)
    rescue *NETWORK_ERRORS => e
      # Only the exception class: the message can echo the request URL, which must stay free of credentials.
      raise NetworkError, "BAND request failed (#{e.class})"
    end

    # BAND reports failures as JSON with a non-1 result_code, often alongside a 4xx status, so the body is parsed
    # before the HTTP status is consulted. A body that isn't BAND's answer is a plain error for a 4xx (a rejection) but
    # an uncertain outcome for a 5xx.
    #: (Net::HTTPResponse response) -> Hash[String, untyped]
    def parse(response)
      body = JSON.parse(response.body.to_s)
      code = body["result_code"] if body.is_a?(Hash)
      raise unreadable_response(response, "an unexpected response") unless code.is_a?(Integer)

      data = body["result_data"]
      data = empty_data unless data.is_a?(Hash)
      return data if code == SUCCESS_CODE

      raise APIError.new(code, error_message(data))
    rescue JSON::ParserError
      raise unreadable_response(response, "a non-JSON response")
    end

    #: (Net::HTTPResponse response, String what) -> Error
    def unreadable_response(response, what)
      error_class = response.code.to_i >= 500 ? UncertainResponseError : Error
      error_class.new("BAND returned #{what} (HTTP #{response.code})")
    end

    #: () -> Hash[String, untyped]
    def empty_data
      {}
    end

    #: (Hash[String, untyped] data) -> String
    def error_message(data)
      [data["message"], data["detail"]].compact.join(": ").then { |text| text.empty? ? "unknown error" : text }
    end
  end
end
