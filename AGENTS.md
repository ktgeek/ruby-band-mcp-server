# AGENTS.md

Guidance for AI coding agents working in this repository. `CLAUDE.md` is a symlink to this file.

## Project

An MCP (Model Context Protocol) server for the [BAND Open API](https://developers.band.us/develop/guide/api), written
in Ruby on the official [`mcp` gem](https://github.com/modelcontextprotocol/ruby-sdk) and served over stdio.

## Setup

```sh
chruby ruby-4.0.5          # or any manager that reads .ruby-version
bundle install
cp .env.example .env       # then set BAND_ACCESS_TOKEN
```

## Commands

Run these under `bundle exec`. `rake` with no arguments runs rubocop, `rbs:drift`, steep, and the specs, which is what
CI checks; `rake -T` lists the individual tasks.

- `rake rbs:generate` (or `rbs-inline --output=sig/generated lib`) regenerates `sig/generated/` after changing
  annotations in `lib/`; commit the result. `rake rbs:drift` fails if the committed output is stale.
- `rake audit` checks `Gemfile.lock` against the Ruby advisory database. It needs the network.
- `rbs collection install` fetches third-party RBS into the git-ignored `.gem_rbs_collection/` (pinned by
  `rbs_collection.lock.yaml`).
- `steep check` type-checks `lib/` against `sig/`.
- `rspec` runs the specs in `spec/`; they mirror the layout of `lib/`.
- `rubocop` lints.

## Workflow

- `main` is protected. Never commit to it directly: work on a branch, open a PR, and wait for green CI.
- CI (`.github/workflows/ci.yml`) runs four parallel jobs on every PR: `lint`, `typecheck` (rbs drift + steep), `test`,
  and `audit`. Dependabot proposes weekly bundler and GitHub Actions updates.
- Land each logical change as its own small commit that leaves the tree working.
- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/): lowercase
  imperative subject of 50 characters (72 at most), body wrapped at 72.
- Keep this file current: when a change adds a command, task, or architectural piece, document it here in the same
  commit.

## Conventions

- Ruby 4.0 (see `.ruby-version`). Style is enforced by RuboCop (with `rubocop-performance` and `rubocop-rspec`):
  double-quoted strings, `# frozen_string_literal: true`, 120-character lines.
- Everything under `lib/` is typed with [rbs-inline](https://github.com/soutaro/rbs-inline) annotations and checked
  by Steep at its strict level. Never edit `sig/generated/` by hand; regenerate it. `sig/shims/` holds hand-written
  `untyped` stubs for gems that ship no RBS (`mcp`, `dotenv`).
- stdout belongs to the MCP protocol. Anything that is not a JSON-RPC message (logs, diagnostics) goes to stderr.
- `BAND_ACCESS_TOKEN` is a secret. Never log it, echo it in a tool response, or commit `.env`.

## BAND API notes

- Base URL: `https://openapi.band.us`.
- Authentication is a bearer token: send `Authorization: Bearer <access_token>` on every request. BAND's published
  docs list `access_token` as a request parameter instead, but the header was verified against the live API and keeps
  the token out of URLs.
- Version prefixes differ per endpoint (`/v2/…`, `/v2.1/…`, `/v2.2/…`), so the client must carry a version per
  endpoint rather than one global prefix.
- Paged responses return `next_params`, which is passed back to fetch the next page.
- The token is issued for an app registered at `https://developers.band.us`. This server only consumes it and runs no
  OAuth flow.

## Architecture

- `bin/band-mcp-server` is a thin launcher: it sets up Bundler and the load path, loads `.env`, and runs the stdio
  transport. It holds no logic.
- `lib/band_mcp.rb` requires the pieces and exposes `BandMCP.build_server`, which registers every class in
  `BandMCP::TOOLS`.
- `lib/band_mcp/config.rb` owns environment access (`.env` loading, `BAND_ACCESS_TOKEN`). Existing ENV values win over
  `.env`.
- `lib/band_mcp/client.rb` is the BAND HTTP client (`Net::HTTP`). `get`/`post` take the full versioned path, return
  `result_data`, and raise `BandMCP::Error` (`lib/band_mcp/error.rb`; `APIError` when BAND reports a failing
  `result_code`). Error messages must never contain the token or the request URL.
- Specs stub HTTP with WebMock, which also fails any unstubbed request, so specs never reach the network.
- `lib/band_mcp/tools/` holds one `MCP::Tool` subclass per tool. To add a tool, create the class there and append it
  to `BandMCP::TOOLS`. BAND-backed tools `extend BandMCP::Tools::Helpers` (`lib/band_mcp/tools/helpers.rb`): wrap the
  work in `with_client { |client| … }` so a `BandMCP::Error` becomes an MCP error response, and answer with
  `json_response`. Answer a response of the wrong shape with `unexpected_format`. A write tool should rescue
  `BandMCP::NetworkError` and answer with `uncertain_outcome`, because a dropped connection doesn't say whether the
  write happened. A paged list answers with `paged_response`, which passes on only the cursor because BAND's
  `next_params` carries the access token.
