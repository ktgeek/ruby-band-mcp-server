# BAND API discrepancies

Places where the live BAND Open API did not match [its documentation](https://developers.band.us/develop/guide/api),
or where the docs say nothing and we found out the hard way. Everything here was observed through this server against
the real API unless an entry says otherwise. The PR numbers point to the discussion and the live checks.

When you find another difference, add it here in the same commit as the code that works around it.

## Where the docs and the API disagree

### Authentication goes in a header, not a parameter

- **Docs**: every endpoint lists `access_token` as a request parameter.
- **Live**: `Authorization: Bearer <token>` works on every endpoint we use.
- **We do**: send the header, which keeps the token out of URLs and logs. (#3)

### `next_params` hands back the access token

- **Docs**: paged responses return `next_params`, to be passed back as query parameters. The docs' own example
  includes `access_token`.
- **Live**: it does, in plain text, next to the cursor.
- **We do**: pass on only the cursor, as `next_after`, from both paged tools (`list_posts` and `list_comments`). Each
  has a spec asserting the token never appears in the output. (#4, #9)

### `get_posts` ignores `limit` and sends no `latest_comments`

- **Docs**: a `limit` parameter, and a `latest_comments` list on each post.
- **Live**: the page size is a fixed 20 whatever `limit` says, and `latest_comments` never appears.
- **We do**: offer neither. Use `list_comments` for a post's comments. (#4)

### Comment `sort` is not what the docs describe

- **Docs**: `+created_at` sorts by creation date and `-created_at` by last modification date; the default is creation
  date.
- **Live**: with no `sort`, comments come oldest first. With `+created_at` or `-created_at`, both come newest first,
  identical to each other.
- **We do**: `list_comments` offers a `newest_first` flag that sends `-created_at`, instead of two values that do the
  same thing. (#9)

### The comments docs cite the posts endpoint for paging

- **Docs**: the paging example on the "Get Comments" page calls `https://openapi.band.us/v2/band/posts?...`. This is
  a copy-paste slip in the docs, not something we saw the API do.
- **Live**: `/v2/band/post/comments` pages with the same cursor shape as posts, 20 comments a page when tested. A post with 45
  comments came back as pages of 20, 20 and 5 in both orders, with no duplicates or gaps.
- **We do**: page that endpoint. (#9, and the paging runs of 2026-10-21 on Keith's Test Band: 45 comments, then 23 through the final tool)

### A comment cursor only works with the sort it came from

- **Docs**: say nothing about it. `next_params` carries the cursor, and everything needed to repeat the request.
- **Live**: a cursor from a `-created_at` listing, followed without the sort, returned 19 comments in ascending order
  starting partway through the post. That skips comments and repeats others, with no error.
- **We do**: `list_comments` puts the order into the `next_after` it returns (`oldest:<cursor>` or `newest:<cursor>`)
  and takes the order from `after`, so it cannot be mismatched. A bare cursor is refused.

### The permissions response shows two key names

- **Docs**: the field table names the result key `permissions`; the example response shows `permission`.
- **Live**: `permissions`, a list of the granted names. Only a band where all three were granted has been read, so
  what BAND sends for partial or empty grants is not known (see "Not verified").
- **We do**: `check_permissions` reads only `permissions`. A response with just `permission` is reported as an
  unexpected format instead of as everything denied. (#6)

## What the docs leave out

### Writes are rate limited ("Cool down time restriction")

- **Live**: some writes are refused with `result_code` 1003, "Cool down time restriction":
  - `remove_post` a few seconds after `create_post`;
  - `remove_comment` immediately after another `remove_comment`.

  The `remove_post` retry worked about 90 seconds later; the `remove_comment` repeat was not retried. A 20-second gap
  was enough between `create_post` and `create_comment`, and between `create_comment` and `remove_comment`. The exact
  window, and which pairs of writes trigger it, are unknown.
- **We do**: say so in the `remove_post` and `remove_comment` descriptions, so a model waits and retries instead of
  giving up. (#7, #11)

### A deleted post is an error, not an empty result

- **Live**: `get_post` on a removed post fails with `result_code` 1000, "Deleted or cannot be found".
- **We do**: `remove_post` tells the model, after a dropped connection, that this answer means the removal worked.
  (#7)

### `comment_key` is only unique within a post

- **Docs**: call it the "Comment ID".
- **Live**: the same `comment_key` (the first comment's) turned up on three different posts.
- **We do**: every comment tool takes `post_key` as well, and `remove_comment`'s description says the key only means
  something together with it. (#11)

### Creating a comment returns no key

- **Docs**: the response is just `{"message": "success"}`, and so it is.
- **Consequence**: there is no `comment_key` to hand back. Find the new comment with `list_comments`.
- **We do**: say so in the `create_comment` description and the README. (#10)

### `get_posts` requires a `locale`

- **Live**: the request fails without one.
- **We do**: `list_posts` defaults it to `en_US` and rejects an empty value. (#4)

### Endpoint versions differ

- `/v2/…`, `/v2.1/…` and `/v2.2/…` are mixed (for example `GET /v2.1/band/post` but `GET /v2/band/posts`, and
  `POST /v2.2/band/post/create`). The client takes a full versioned path per call.

## Not verified

These come from the docs only. Do not rely on them without trying.

- **Permissions when none are granted**: we only saw bands where everything is granted. If BAND omits the list in that
  case, `check_permissions` reports an error. (#6)
- **Authorship**: the docs say `contents_deletion` does not check who wrote a post or comment, and that
  `remove_comment` only works on comments made through the same app. The test band has one member, so neither was
  tried. The tools pass BAND's refusal on. (#7, #11)
- **Removing something already removed**: the one attempt hit the cool-down instead. (#11)
