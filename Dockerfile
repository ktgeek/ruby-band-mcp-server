# Installs the released gem from RubyGems rather than building the checkout, so the image holds exactly what users get
# from `gem install`. The release workflow passes the tag's version.
FROM ruby:4.0-slim

ARG VERSION

# The MCP Registry reads this label to match the image to its server entry. The OCI source and license labels come from
# docker/metadata-action in the release workflow.
LABEL io.modelcontextprotocol.server.name="io.github.ktgeek/band-mcp-server"

RUN test -n "$VERSION" || { echo "build with --build-arg VERSION=<gem version>" >&2; exit 1; } \
    && gem install band-mcp-server --version "$VERSION" --no-document

# Nothing the server does needs root.
USER nobody

# The token comes from the environment (`docker run -e BAND_ACCESS_TOKEN`); there is no config file in the image.
ENTRYPOINT ["band-mcp-server"]
