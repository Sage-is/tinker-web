# tinker-web

Web Tinker (upstream's tenkts-server with TENKTS_WEB=1) in a container, built unmodified from a pinned upstream commit.

## Read this first

- Upstream says, “Never put it on a public address.” Web mode is still for internal use: there are no approvals, and a generated app in the shared map is readable by anyone who knows its id.
- Generated apps share the server's domain. Anyone who goes further should set `TENKTS_WEB_APP_HOST` to a domain of its own, and read upstream's [`docs/WEB-DESIGN.md`](https://github.com/tinker-click/tinker-click/blob/main/docs/WEB-DESIGN.md) first.
- The image stays invite-only with `TENKTS_SERVER_ALLOW=@invalid`. Publish the server on `127.0.0.1` only.

## Run it

`TENKTS_WEB_NODE_TOKEN` is a session token for your account on the node (see [The model](#the-model)). Put it in your shell's environment, so it never sits on the command line: `export TENKTS_WEB_NODE_TOKEN=...` on macOS and Linux, or `$env:TENKTS_WEB_NODE_TOKEN = "..."` in PowerShell. Then:

```sh
docker run -d --name tinker-web -p 127.0.0.1:8799:8799 -v tinker-web-data:/data -e TENKTS_WEB_NODE_TOKEN ghcr.io/sage-is/tinker-web:latest
```

Make invite codes. Each works once, and they print only this once; an account made with one needs no confirmation email:

```sh
docker exec tinker-web tinker-cli invites new --name demo --count 3
```

Open <http://localhost:8799>, not `127.0.0.1`. Generated apps open at `<id>.widget.localhost:8799`, and only names under `localhost` resolve without DNS. Without the token, the page serves and saved apps open, but nothing new can be built.

From another machine, tunnel instead of publishing the port: `ssh -L 8799:127.0.0.1:8799 <server>`, then open <http://localhost:8799> there.

## The model

At start, the server sends `GET $TENKTS_WEB_NODE/v1/model-login` with the token as a bearer, once, with a 20-second timeout. A `200` response supplies a JSON login; `204` means no model login; `401` means the node refused the token. Any server that answers this request can be the node.

## Settings

### Set by this image

| Variable | This image | Upstream default |
| --- | --- | --- |
| `TENKTS_WEB` | `1` | unset |
| `TENKTS_SERVER_BIND` | `0.0.0.0:8799` | `127.0.0.1:8787` |
| `TENKTS_SERVER_DATA` | `/data` | `./data` |
| `TENKTS_WEB_UI` | `/srv/ui` | `ui` |
| `TENKTS_SERVER_ALLOW` | `@invalid` | unset (server will not start) |

### Everything else

| Variable | Default | Meaning |
| --- | --- | --- |
| `TENKTS_WEB_NODE` | `https://app.tinker.click` | Node that supplies the model login. |
| `TENKTS_WEB_NODE_TOKEN` | unset | Session token used to request the model login. |
| `TENKTS_WEB_ACCOUNTS` | `local` | Use `node` for node accounts instead of local accounts. |
| `TENKTS_WEB_APP_HOST` | unset: `widget.<the page's host>` | Domain for generated apps. |
| `TENKTS_SERVER_SECRET` | unset: `model-logins.key` in the data folder, made on first start | Secret that seals model login API keys in the database. |
| `TENKTS_SERVER_PUBLIC_URL` | unset | Public address; needed only for Google, GitHub, or Apple sign-in. |
| `TENKTS_SERVER_GOOGLE_CLIENT_ID`, `TENKTS_SERVER_GOOGLE_CLIENT_SECRET` | unset | Google OAuth client credentials. |
| `TENKTS_SERVER_GITHUB_CLIENT_ID`, `TENKTS_SERVER_GITHUB_CLIENT_SECRET` | unset | GitHub OAuth app credentials. |
| `TENKTS_SERVER_APPLE_CLIENT_ID` | unset | Apple Sign In Services ID. |
| `TENKTS_SERVER_APPLE_TEAM_ID`, `TENKTS_SERVER_APPLE_KEY_ID`, `TENKTS_SERVER_APPLE_PRIVATE_KEY` | unset | Apple team and Sign in with Apple key details. |
| `TENKTS_SERVER_PASSWORDS` | `on` | Set `off` to disable email-and-password registration. |
| `TENKTS_SERVER_SITE_URL` | `https://tinker.click` | Website used to build published-app links. |
| `TENKTS_SERVER_RATINGS` | `on` | Set `off` to disable ratings and comments on public apps. |
| `TENKTS_SERVER_MAX_UPLOAD_MB` | `3` | Maximum file size, in MB, for user-added files. |
| `TENKTS_SERVER_DEFAULT_ROLE` | `user` | Role assigned to new accounts; first account is always administrator. |
| `TENKTS_SERVER_LATEST_VERSION` | unset | Newest desktop version; older copies are asked to update. |
| `TENKTS_SERVER_MIN_VERSION` | unset | Older copies must update at every start. |
| `TENKTS_SERVER_DOWNLOAD_URL` | unset | HTTPS page for the newest desktop version. |
| `TENKTS_SERVER_RELEASE_NOTES` | unset | Release note shown with the update notice. |
| `TENKTS_SERVER_SMTP_HOST` | unset | SMTP server for email and address-confirmation links. |
| `TENKTS_SERVER_SMTP_SECURITY` | `starttls` | SMTP security: `starttls`, `ssl`, or `none`. |
| `TENKTS_SERVER_SMTP_PORT` | `587` (`starttls`), `465` (`ssl`), `25` (`none`) | SMTP port for the selected security mode. |
| `TENKTS_SERVER_SMTP_USER`, `TENKTS_SERVER_SMTP_PASSWORD` | unset | SMTP sign-in credentials. |
| `TENKTS_SERVER_MAIL_FROM` | unset | Sender address; required with an SMTP host. |
| `TENKTS_SERVER_MAIL_DAILY_LIMIT` | `50` | Maximum emails one account may send in 24 hours. |
| `TENKTS_SERVER_ERRORS_KEY` | unset | Secret of at least 32 characters that enables reading error reports. |

Each `TENKTS_SERVER_*` secret may instead come from a file: set `<NAME>_FILE` to its path. The `TENKTS_WEB_*` variables, the node token included, do not take `_FILE`.

## More

- [Running the image](docs/running.md)
- [Upstream pin](docs/pin.md)
- [Licence](docs/licence.md)

Run `make help` to list project commands. Run `make it_build` to build the image.

## Licence

AGPL-3.0-only, upstream's. See [docs/licence.md](docs/licence.md).
