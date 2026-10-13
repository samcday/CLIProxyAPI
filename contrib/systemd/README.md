# Running CLIProxyAPI as a systemd user service

These files run a single-user CLIProxyAPI on `127.0.0.1:8317` under
`systemctl --user`, without root. The setup is intended for using an OAuth
subscription (for example, Claude) and API-key subscriptions (for example, a
MiMo Token Plan) from a desktop client that accepts a custom OpenAI- or
Anthropic-compatible provider.

| File | Install to |
| --- | --- |
| `cliproxyapi` | `~/.local/bin/cliproxyapi` (mode 0755) |
| `cliproxyapi.service` | `~/.config/systemd/user/cliproxyapi.service` |
| `config.example.yaml` | `~/.config/cliproxyapi/config.yaml` |

Keys live in their own files under `~/.config/cliproxyapi` (mode 0600), so
the configuration holds no secrets. The configuration format has no
environment or file expansion. At startup, the wrapper replaces each
`@NAME@` placeholder with the contents of the corresponding key file.
The filename uses lowercase letters and changes `_` to `-`.
For example, `@CLIENT_API_KEY@` reads `client-api-key`, and
`@MIMO_API_KEY@` reads `mimo-api-key`.

Each placeholder must be a complete double-quoted property or list-item
value, such as `api-key: "@MIMO_API_KEY@"` or `- "@CLIENT_API_KEY@"`.
The wrapper leaves comments and other text unchanged.
Commented-out providers do not need key files. A missing key file for an
active placeholder stops the startup.

The wrapper runs the server with the rendered configuration at
`~/.local/state/cliproxyapi/config.yaml` (mode 0600).
Edit the configuration or a key file in `~/.config`, then run
`cliproxyapi render`. It rewrites the rendered copy in place, and the running
service reloads it within a few seconds without a restart. Do not edit the
rendered copy: the wrapper overwrites it on each start and render. A restart is
only needed for a new binary, wrapper, or unit file.

The wrapper expects the server binary at
`~/.local/share/cliproxyapi/cli-proxy-api`. Override the binary, config, key
directory, client key file, or working directory with `CLIPROXYAPI_BIN`,
`CLIPROXYAPI_CONFIG`, `CLIPROXYAPI_KEY_DIR`, `CLIPROXYAPI_KEY_FILE`, or
`CLIPROXYAPI_STATE`.

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
# MiMo Token Plan key (tp-...), or delete the api-keys.claude group from the config.
(umask 077 && printf '%s\n' 'tp-...' > ~/.config/cliproxyapi/mimo-api-key)

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

The Claude login serves the `claude-*` models; the MiMo key serves only the
`mimo-*` models listed in the config (select one with `/model` in Claude Code
or `ANTHROPIC_MODEL`). The Token Plan has no `count_tokens` endpoint, so the
proxy estimates MiMo token counts locally.

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

## Test the wrapper

Run the tests from the repository root. The tests use dummy keys and a dummy
server binary in a temporary directory. They do not read your credentials or
restart your service.

```sh
sh contrib/systemd/cliproxyapi_test.sh
shellcheck contrib/systemd/cliproxyapi contrib/systemd/cliproxyapi_test.sh
```
