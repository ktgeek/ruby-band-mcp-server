# ruby-band-mcp-server

An [MCP](https://modelcontextprotocol.io) server for the [BAND Open API](https://developers.band.us/develop/guide/api),
written in Ruby on the official [`mcp` gem](https://github.com/modelcontextprotocol/ruby-sdk) and served over stdio.

## Tools

| Tool                | What it does                                                                                   |
| ------------------- | ---------------------------------------------------------------------------------------------- |
| `ping`              | Reports that the server is up and whether `BAND_ACCESS_TOKEN` is configured (never its value). |
| `list_bands`        | Lists the bands you have joined, with the `band_key` the other tools need.                     |
| `create_post`       | Publishes a text post to a band. Members are push-notified only if `do_push` is true.          |
| `get_post`          | Fetches one post by `band_key` and `post_key`, e.g. to confirm a `create_post` landed.         |
| `list_posts`        | Lists a band's recent posts, newest-modified first, paged with an `after` cursor.              |
| `check_permissions` | Reports which of `posting`, `commenting` and `contents_deletion` the user has in a band.       |
| `remove_post`       | Permanently deletes a post by `band_key` and `post_key`. It cannot be undone.                  |
| `list_comments`     | Lists a post's comments, oldest first unless `newest_first`, paged with `after`.               |
| `create_comment`    | Adds a comment to a post. BAND does not return its key; find it with `list_comments`.          |
| `remove_comment`    | Permanently deletes a comment by `comment_key`. It cannot be undone.                           |

A typical flow is `list_bands` to find the band, `create_post` to publish, then `get_post` with the returned
`post_key` to confirm. `create_post` is marked as not read-only, so MCP clients such as Claude Desktop can ask before
running it.

To browse what is already in a band, use `list_posts`. BAND picks the page size (20 posts); when the result's
`next_after` is not null, pass it back as `after` to get the next page.

To read the discussion on a post, use `list_comments` with the post's `band_key` and `post_key`. Comments come oldest
first; set `newest_first` to reverse that. BAND chose a page size of 20 when tested. Pass `next_after` back as `after` exactly as
returned: it remembers the order, so a page after the first needs no `newest_first`.

To join in, use `create_comment`. BAND confirms the comment without saying what its key is, so call `list_comments`
afterwards to confirm it landed and to get its `comment_key`.

To take a post down, use `remove_post`; it is marked destructive, so clients can ask before running it. Run
`check_permissions` with `contents_deletion` first. BAND's docs say that permission does not check authorship, so
removing someone else's post can still fail. `remove_comment` works the same way on a `comment_key` from
`list_comments`, and BAND's docs add that it can only remove comments made through this app.

## Requirements

Ruby 4.0 or newer.

## Install

```sh
gem install band-mcp-server
```

This puts a `band-mcp-server` executable on your `PATH`. To run it without installing, RubyGems can fetch and run it
on demand (the gem and executable share a name, but `gem exec` needs the gem named explicitly):

```sh
gem exec -g band-mcp-server band-mcp-server
```

### Getting a BAND access token

Register an app on the [BAND developer site](https://developers.band.us) and get an access token for it; the
[API guide](https://developers.band.us/develop/guide/api) covers the details. The server only consumes the token and
sends it to BAND as an `Authorization: Bearer` header. It does not run any OAuth flow itself.

### Configuring the token

Put the token in `~/.config/band-mcp-server/config` (or `$XDG_CONFIG_HOME/band-mcp-server/config` if you set that):

```sh
mkdir -p ~/.config/band-mcp-server
echo 'BAND_ACCESS_TOKEN=your-token' > ~/.config/band-mcp-server/config
chmod 600 ~/.config/band-mcp-server/config
```

A value already set in the environment (for example through the MCP client's `env` setting) takes precedence over
the file.

## Running

Register it with Claude Code:

```sh
claude mcp add band -- band-mcp-server
```

The server speaks MCP over stdio, so it is normally launched by a client rather than run by hand.

### Claude Desktop

Claude Desktop starts servers with a minimal environment, so a version manager such as chruby is not active and
the installed executable's `#!/usr/bin/env ruby` finds the wrong Ruby (the system Ruby, if any). With chruby, launch
the server through [`chruby-exec`](https://github.com/postmodern/chruby#chruby-exec), which selects the Ruby and its
`GEM_HOME` for you.

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
         "args": ["ruby-4", "--", "band-mcp-server"]
       }
     }
   }
   ```

   chruby matches `ruby-4` against the installed Rubies by name, so it picks a 4.x Ruby; use a fuller name such as
   `ruby-4.0.5` to pin one. Run `gem install band-mcp-server` under that same Ruby.

   Keep the token in the config file described above; it is loaded by absolute path, so the working directory does not
   matter. Setting `BAND_ACCESS_TOKEN` in an `env` map instead also works and takes precedence, but puts the secret in
   Desktop's config file.

   Without chruby, use the absolute path of the installed executable (`which band-mcp-server`) as `command`. If that
   Ruby is not the first `ruby` on Desktop's minimal `PATH`, use the absolute path of a Ruby 4.0 or newer as `command`
   instead, put the executable in `args`, and set `GEM_HOME` to the directory holding the installed gems
   (`gem env gemdir` prints it):

   ```json
   {
     "mcpServers": {
       "band": {
         "command": "/path/to/ruby",
         "args": ["/path/to/band-mcp-server"],
         "env": { "GEM_HOME": "/path/to/gem/dir" }
       }
     }
   }
   ```
3. Quit Claude Desktop completely (Cmd-Q) and reopen it. The `band` tools appear in the tools menu of a new chat.

Then ask Claude to run `ping`, which reports whether the token is set without showing it, and try "Which bands am I
in?" to confirm the connection. Desktop asks before it runs a tool unless you have set that tool to always allow.
Keep the prompt on for `create_post` and `create_comment`: they publish to every member of the band. Read the band and
the wording in the request before approving. For `create_post`, members are push-notified only if the request sets
`do_push`. Keep the prompt on for `remove_post` and `remove_comment` too: what they delete is gone for every member and
cannot be restored, so check the keys before approving.

To check the launch command outside Desktop, run it with a bare environment. A JSON `initialize` response means the
server starts under that Ruby with its gems; it does not check the token, which `ping` does:

```sh
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"check","version":"0"}}}' |
  env -i HOME="$HOME" PATH=/usr/bin:/bin "$(which chruby-exec)" ruby-4 -- band-mcp-server
```

If the tools do not show up, read `~/Library/Logs/Claude/mcp-server-band.log`:

| Symptom in the log or tool result               | Cause                                                                          |
| ----------------------------------------------- | ------------------------------------------------------------------------------ |
| `spawn … ENOENT`                                | `command` is not an absolute path to an existing `chruby-exec` (or Ruby).      |
| `chruby: unknown Ruby: …`                       | No installed Ruby matches the name in `args`; compare with the output of `chruby`. |
| `Could not find dotenv-…, mcp-…` (gems missing) | `gem install` was run under a different Ruby; run it under the one in args.  |
| `requires Ruby version >= 4.0`                  | The chosen Ruby is older than 4.0; point `args` (or `command`) at a 4.x Ruby.  |
| `BAND_ACCESS_TOKEN is not set`                  | No config file with the token, and no `BAND_ACCESS_TOKEN` in an `env` map.     |
| `command not found: chruby`                     | chruby is only loaded in `~/.zshrc`; load it in `~/.zprofile` or `~/.zshenv`.  |
| Desktop cannot parse the server's output        | A shell startup file prints to stdout; `chruby-exec` runs a login shell.       |
| `BAND API error 10401`                          | BAND's "Unauthorized" code: the token is missing, invalid or expired.          |

## Development

From a checkout, use Bundler instead of the installed gem. A `.env` in the checkout root takes priority over the
user config file, and `bin/band-mcp-server` (which sets up Bundler itself) replaces `band-mcp-server`:

```sh
chruby ruby-4.0.5   # or any manager that reads .ruby-version
bundle install
cp .env.example .env    # then set BAND_ACCESS_TOKEN
claude mcp add band -- /path/to/ruby-band-mcp-server/bin/band-mcp-server
```

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
