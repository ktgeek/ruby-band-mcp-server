# ruby-band-mcp-server

An [MCP](https://modelcontextprotocol.io) server for the [BAND Open API](https://developers.band.us/develop/guide/api),
written in Ruby on the official [`mcp` gem](https://github.com/modelcontextprotocol/ruby-sdk) and served over stdio.

It is early: the only tool so far is `ping`, which reports that the server is up and whether `BAND_ACCESS_TOKEN` is
configured (never its value). The BAND tools come next.

## Requirements

Ruby 4.0.5 (see `.ruby-version`), for example with [chruby](https://github.com/postmodern/chruby):

```sh
chruby ruby-4.0.5
```

## Setup

```sh
bundle install
cp .env.example .env    # then set BAND_ACCESS_TOKEN
```

### Getting a BAND access token

Register an app on the [BAND developer site](https://developers.band.us) and get an access token for it; the
[API guide](https://developers.band.us/develop/guide/api) covers the details. The server only consumes the token and
sends it to BAND as an `Authorization: Bearer` header. It does not run any OAuth flow itself.

A value already set in the environment (for example through the MCP client's `env` setting) takes precedence over
`.env`.

## Running

Register it with Claude Code:

```sh
claude mcp add band -- /path/to/ruby-band-mcp-server/bin/band-mcp-server
```

The server speaks MCP over stdio, so it is normally launched by a client rather than run by hand.

## Development

```sh
bundle exec rake    # rubocop, rbs drift check, steep, rspec
bundle exec rake -T # every task, including audit
```

`lib/` is typed with [rbs-inline](https://github.com/soutaro/rbs-inline) annotations and checked by
[Steep](https://github.com/soutaro/steep); regenerate `sig/generated/` with `bundle exec rake rbs:generate` after
changing them. See [AGENTS.md](AGENTS.md) for conventions and architecture.

`main` is protected: changes land through a pull request with green CI.

## License

GPL-3.0. See [LICENSE](LICENSE).
