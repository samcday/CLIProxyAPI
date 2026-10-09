# Running CLIProxyAPI as a systemd user service

These files run a single-user CLIProxyAPI on `127.0.0.1:8317` under
`systemctl --user`, without root. The setup is intended for using an OAuth
subscription (for example, Claude) from a desktop client that accepts a
custom OpenAI- or Anthropic-compatible provider.

| File | Install to |
| --- | --- |
| `cliproxyapi` | `~/.local/bin/cliproxyapi` (mode 0755) |
| `cliproxyapi.service` | `~/.config/systemd/user/cliproxyapi.service` |
| `config.example.yaml` | `~/.config/cliproxyapi/config.yaml` |

The client key lives in its own file, `~/.config/cliproxyapi/client-api-key`
(mode 0600), so the config holds no secrets. The config format has no
environment or file expansion, so on every start the wrapper substitutes the
key for `@CLIENT_API_KEY@` and runs the server against the rendered copy at
`~/.local/state/cliproxyapi/config.yaml` (mode 0600). Edit the config in
`~/.config`, then restart the service; edits to the rendered copy are
overwritten.

The wrapper expects the server binary at
`~/.local/share/cliproxyapi/cli-proxy-api`. Override the binary, config, key
file, or working directory with `CLIPROXYAPI_BIN`, `CLIPROXYAPI_CONFIG`,
`CLIPROXYAPI_KEY_FILE`, or `CLIPROXYAPI_STATE`.

## Install

```sh
# Binary: build from source, or download a release and verify it against checksums.txt.
mkdir -p ~/.local/share/cliproxyapi
go build -o ~/.local/share/cliproxyapi/cli-proxy-api ./cmd/server

install -Dm755 contrib/systemd/cliproxyapi ~/.local/bin/cliproxyapi
install -Dm644 contrib/systemd/cliproxyapi.service ~/.config/systemd/user/cliproxyapi.service

install -Dm644 contrib/systemd/config.example.yaml ~/.config/cliproxyapi/config.yaml
# Generate a client key (or write your own key to this file).
(umask 077 && openssl rand -hex 32 > ~/.config/cliproxyapi/client-api-key)

systemctl --user daemon-reload
systemctl --user enable --now cliproxyapi.service
```

## Authenticate

Run the login in your own terminal and finish it in the browser. The server
picks up new credentials without a restart.

```sh
cliproxyapi --claude-login
```

Credentials are stored under `~/.local/share/cliproxyapi/auth/`. Keep that
directory private.

## Connect a client

For an Anthropic Messages client, use base URL `http://127.0.0.1:8317` (clients
add `/v1/messages`). For an OpenAI Chat Completions client, use
`http://127.0.0.1:8317/v1`. In both cases the API key is the contents of
`~/.config/cliproxyapi/client-api-key`.

## Operate

```sh
systemctl --user status cliproxyapi.service
journalctl --user -u cliproxyapi.service -f -o cat | grep -E ' (4|5)[0-9]{2} \||served model'
```

The service fetches the model catalog at startup and every 3 hours, so newly
released models become routable without upgrading the binary. To pin the
catalog embedded in the binary instead, add `--local-model` to `ExecStart`.

Subscription providers may bill proxied requests differently from their own
clients; for Claude, keep paid extra usage disabled until you have confirmed
requests draw from plan limits.
