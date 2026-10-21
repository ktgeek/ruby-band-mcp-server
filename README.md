# ruby-band-mcp-server

An [MCP](https://modelcontextprotocol.io) server for the [BAND Open API](https://developers.band.us/develop/guide/api),
written in Ruby on the official [`mcp` gem](https://github.com/modelcontextprotocol/ruby-sdk) and served over stdio.

## Tools

| Tool          | What it does                                                                                    |
| ------------- | ----------------------------------------------------------------------------------------------- |
| `ping`        | Reports that the server is up and whether `BAND_ACCESS_TOKEN` is configured (never its value).  |
| `list_bands`  | Lists the bands you have joined, with the `band_key` the other tools need.                      |
| `create_post` | Publishes a text post to a band. Members are push-notified only if `do_push` is true.           |
| `get_post`    | Fetches one post by `band_key` and `post_key`, e.g. to confirm a `create_post` landed.          |
| `list_posts`  | Lists a band's recent posts, newest-modified first, paged with an `after` cursor.               |

A typical flow is `list_bands` to find the band, `create_post` to publish, then `get_post` with the returned
`post_key` to confirm. `create_post` is marked as not read-only, so MCP clients such as Claude Desktop can ask before
running it.

To browse what is already in a band, use `list_posts`. BAND picks the page size (20 posts); when the result's
`next_after` is not null, pass it back as `after` to get the next page.

## Requirements

Ruby 4.0 or newer (the Gemfile requires `>= 4.0`). Development and CI use the version in `.ruby-version`, currently
4.0.5, for example with [chruby](https://github.com/postmodern/chruby):

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

### Claude Desktop

Claude Desktop starts servers with a minimal environment, so a version manager such as chruby is not active and
`#!/usr/bin/env ruby` finds the wrong Ruby (the system Ruby, if any). With chruby, launch the server through
[`chruby-exec`](https://github.com/postmodern/chruby#chruby-exec), which selects the Ruby and its `GEM_HOME` for you.

`chruby-exec` does that by running the command in a login shell (`$SHELL -l -c`), so two things must hold. chruby has
to be loaded by a startup file that a non-interactive login shell reads (for zsh, `~/.zprofile` or `~/.zshenv`, not
only `~/.zshrc`). And those startup files must not print anything to stdout: it would land in front of the protocol
stream and Desktop could not parse the handshake.

1. Find where `chruby-exec` is installed with `which chruby-exec`. That depends on how you installed chruby, and the
   path has to be absolute because Desktop's `PATH` is minimal.
2. Open Settings → Developer → Edit Config (on macOS this is
   `~/Library/Application Support/Claude/claude_desktop_config.json`) and add a `band` entry to `mcpServers`:

   ```json
   {
     "mcpServers": {
       "band": {
         "command": "/path/to/chruby-exec",
         "args": ["ruby-4", "--", "ruby", "/path/to/ruby-band-mcp-server/bin/band-mcp-server"]
       }
     }
   }
   ```

   chruby matches `ruby-4` against the installed Rubies by name, so it picks a 4.x Ruby; use a fuller name such as
   `ruby-4.0.5` to pin one. Run `bundle install` under that same Ruby.

   Keep the token in `.env`; the launcher loads it by absolute path, so the working directory does not matter. Setting
   `BAND_ACCESS_TOKEN` in an `env` map instead also works and takes precedence, but puts the secret in Desktop's
   config file.

   Without chruby, use the absolute path of a Ruby 4.0 or newer that ran `bundle install` as `command`, put the script
   in `args`, and set `GEM_HOME` to the directory holding the installed gems (`gem env gemdir` prints it, unless a
   Bundler setting such as `BUNDLE_PATH` put them elsewhere):

   ```json
   {
     "mcpServers": {
       "band": {
         "command": "/path/to/ruby",
         "args": ["/path/to/ruby-band-mcp-server/bin/band-mcp-server"],
         "env": { "GEM_HOME": "/path/to/gem/dir" }
       }
     }
   }
   ```
3. Quit Claude Desktop completely (Cmd-Q) and reopen it. The `band` tools appear in the tools menu of a new chat.

Then ask Claude to run `ping`, which reports whether the token is set without showing it, and try "Which bands am I
in?" to confirm the connection. Desktop asks before it runs a tool unless you have set that tool to always allow.
Keep the prompt on for `create_post`: it publishes to every member of the band, and nothing here can undo it. Read the
band and the wording in the request before approving. Members are push-notified only if the request sets `do_push`.

To check the launch command outside Desktop, run it with a bare environment. A JSON `initialize` response means the
server starts under that Ruby with its gems; it does not check the token, which `ping` does:

```sh
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"check","version":"0"}}}' |
  env -i HOME="$HOME" PATH=/usr/bin:/bin "$(which chruby-exec)" ruby-4 -- ruby /path/to/ruby-band-mcp-server/bin/band-mcp-server
```

If the tools do not show up, read `~/Library/Logs/Claude/mcp-server-band.log`:

| Symptom in the log or tool result               | Cause                                                                          |
| ----------------------------------------------- | ------------------------------------------------------------------------------ |
| `spawn … ENOENT`                                | `command` is not an absolute path to an existing `chruby-exec` (or Ruby).      |
| `chruby: unknown Ruby: …`                       | No installed Ruby matches the name in `args`; compare with the output of `chruby`. |
| `Could not find dotenv-…, mcp-…` (gems missing) | `bundle install` was run under a different Ruby; run it under the one in args. |
| `Your Ruby version is …, but your Gemfile …`    | The chosen Ruby is older than 4.0; point `args` (or `command`) at a 4.x Ruby.  |
| `BAND_ACCESS_TOKEN is not set`                  | No `.env` with the token, and no `BAND_ACCESS_TOKEN` in an `env` map.          |
| `command not found: chruby`                     | chruby is only loaded in `~/.zshrc`; load it in `~/.zprofile` or `~/.zshenv`.  |
| Desktop cannot parse the server's output        | A shell startup file prints to stdout; `chruby-exec` runs a login shell.       |
| `BAND API error 10401`                          | BAND's "Unauthorized" code: the token is missing, invalid or expired.          |

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
