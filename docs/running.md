# How the image runs

## What starts

The entrypoint, `tinker-web-entrypoint`, checks one thing and then runs the command,
`tenkts-server` by default. When web mode is on (`TENKTS_WEB` set, not `0`) and
`$TENKTS_WEB_UI/index.html` is missing, it exits with status 1. Upstream's server
would instead log `Tinker for the web is off` and keep serving only its library API,
which looks healthy from outside.

`tenkts-server` listens on `0.0.0.0:8799` inside the container. Publish it on the
loopback address only:

```sh
docker run -d --name tinker-web -p 127.0.0.1:8799:8799 -v tinker-web-data:/data \
  ghcr.io/sage-is/tinker-web:<version>
```

Any host port works. The apps Tinker builds open at `<id>.widget.localhost:<port>`;
the server reads the app's id from the request's `Host` header and ignores the port.
`localhost` is the only name whose `*.widget.` subdomains resolve without DNS, so open
the page as `http://localhost:<port>`, not `127.0.0.1`.

## The data volume

`/data` holds everything that lasts: `tinker.sqlite` (with its `-wal` and `-shm`
files), `model-logins.key`, and `backups/`. The server creates them on its first start.
Keep the volume; removing the container does not remove it.

The process runs as user `tinker` (uid 10001). A bind mount instead of a named volume
must be writable by that uid.

## Invite codes and accounts

`TENKTS_SERVER_ALLOW=@invalid` matches no address, so nobody signs up without an invite
code. `tinker-cli` works on the same database, so start the server once first, then:

```sh
docker exec tinker-web tinker-cli invites new --name demo --count 3
docker exec tinker-web tinker-cli help
```

## The model

Web Tinker never holds a provider key. At start it asks a Tinker node for a model
login: `GET $TENKTS_WEB_NODE/v1/model-login` with `TENKTS_WEB_NODE_TOKEN` as the bearer.
Without a token the page still serves and saved apps still open, but no new app can
be built. Pass the token from the environment, not on the command line:

```sh
export TENKTS_WEB_NODE_TOKEN=...
docker run ... -e TENKTS_WEB_NODE_TOKEN ghcr.io/sage-is/tinker-web:<version>
```

## Building

`make it_build` builds for the Docker context in `DOCKER_CONTEXT` (`colima` by default,
which is Colima's `default` profile) and prints the image's labels. The first build
compiles the whole release profile (LTO, one codegen unit); later builds reuse a cache
mount for the registry and `target/`.

`make it_run`, `make it_check`, `make invite`, `make logs` and `make it_stop` run the
same container locally.
