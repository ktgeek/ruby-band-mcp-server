# frozen_string_literal: true

# rbs_inline: enabled

module BandMCP
  # Raised for anything that stops a BAND request from producing a result. The message is safe to show to the model:
  # it never contains the access token.
  class Error < StandardError; end

  # The request failed in transit, so it may or may not have reached BAND. Matters for writes, which must not be blindly
  # retried.
  class NetworkError < Error; end

  # A 5xx whose body isn't BAND's own answer (an HTML error page, say). A gateway in front of BAND can forward a write
  # and then fail, so like a dropped connection it says nothing about whether the write happened.
  class UncertainResponseError < NetworkError; end

  # BAND answered, but with a failure `result_code`. See https://developers.band.us/develop/guide/api/handle_errors.
  class APIError < Error
    attr_reader :code #: Integer

    #: (Integer code, String message) -> void
    def initialize(code, message)
      @code = code
      super("BAND API error #{code}: #{message}")
    end
  end
end
