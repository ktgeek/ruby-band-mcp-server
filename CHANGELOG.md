# Changelog

## Unreleased

- Publish a multi-architecture Docker image to `ghcr.io/ktgeek/band-mcp-server` on each release, for running the
  server with `docker run -i` (see the README).

## v1.0.0

First stable release.

- Serve ten tools over stdio for the BAND Open API: `ping`, `list_bands`, `create_post`, `get_post`, `list_posts`,
  `check_permissions`, `remove_post`, `list_comments`, `create_comment` and `remove_comment`.
- Write tools report an uncertain outcome (dropped connection, or a 5xx that isn't BAND's own JSON) with advice on how
  to check before retrying.
- Package as the `band-mcp-server` gem with a `band-mcp-server` executable.
- Read `BAND_ACCESS_TOKEN` from `~/.config/band-mcp-server/config` when it is not in the environment.
