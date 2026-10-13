---
name: land
description: >-
  Land changes in the samcday/CLIProxyAPI fork and redeploy its local user
  service. Invoke only when the user explicitly requests landing, not for
  review, preparation, or skill installation.
disable-model-invocation: true
metadata:
  delta-action: land
---

# Land

Invocation authorizes this workflow; do not ask for merge permission again.
Handle routine conflicts yourself; stop on ambiguity, failed checks, or risks
to unrelated work. No upstream submissions, releases, force-pushes, or routine backups.

1. **Check the control channel.** Establish whether this session's provider
   uses the proxy being redeployed, for example by matching the proxy's recent
   request log against this session's own turns. A model name alone is not
   proof. If it does, or the route cannot be established, do not stop: warn
   the user that a service restart in step 4 may cut off this turn, and that
   if the turn does not recover after the restart they should retry manually
   or switch to a model that does not route through the proxy. Then continue.

2. **Prepare the candidate.** Verify GitHub authentication, that `origin` is
   the writable `samcday/CLIProxyAPI` fork of `router-for-me/CLIProxyAPI`, and
   the current rules for its `main`. Fetch `origin`, integrate `origin/main`,
   and commit only the intended changes, including relevant uncommitted work.
   Follow `AGENTS.md`, including its conditional permission and testing rules.
   Preserve unrelated edits; use non-interactive commits and merges.

3. **Verify and build.** Use Go >= the version in `go.mod`; format and commit
   any Go changes before running:
   - `go build -o test-output ./cmd/server && rm test-output` (required).
   - `go test ./...` for Go/module changes; relevant tests otherwise.
   - For service changes: `sh contrib/systemd/cliproxyapi_test.sh`,
     `shellcheck contrib/systemd/cliproxyapi contrib/systemd/cliproxyapi_test.sh`,
     and `systemd-analyze --user verify contrib/systemd/cliproxyapi.service`.
     Parse the rendered YAML with the server's config loader.
   - `go build -o cli-proxy-api ./cmd/server` for the deployment artifact.
   Require every applicable local check, remote check, and review to pass for
   this exact candidate. Pending, missing, or unverifiable requirements block
   landing; do not bypass destination protections.
   Sources: `go.mod`, `cmd/server/main.go`, `.github/workflows/pr-test-build.yml`,
   `AGENTS.md`, and `contrib/systemd/cliproxyapi{,.service}`.

4. **Deploy.** Deploy the repository wrapper, unit, and config to their
   documented user-local paths. Respect configured path overrides and preserve
   unrelated local settings. Reuse the existing client-key file and OAuth
   directory: never regenerate, print, or commit credentials. Do not rerun the
   README's key-generation step. Then, by what the candidate changed:
   - Config only (`config.example.yaml`, with the installed binary, wrapper,
     and unit unchanged): run `cliproxyapi render`. The running service
     reloads the rendered config within a few seconds; do not restart.
   - Otherwise: install the built binary at
     `~/.local/share/cliproxyapi/cli-proxy-api`, run
     `systemctl --user daemon-reload`, and restart. If step 1 found this
     session on the proxy, defer the restart past the current turn, for
     example `systemd-run --user --on-active=30 systemctl --user restart
     cliproxyapi.service`, end the turn immediately, and resume in the next
     turn. Otherwise `systemctl --user restart cliproxyapi.service` directly.
   Sources: `contrib/systemd/README.md`, `contrib/systemd/cliproxyapi`,
   `contrib/systemd/cliproxyapi.service`, `contrib/systemd/config.example.yaml`.

5. **Confirm it works.** Check the service is active, remains loopback-only,
   rejects unauthenticated requests, and returns the configured models from
   authenticated `GET /v1/models`. After a config-only deploy, also confirm
   the journal shows the reload and the model list reflects the change. After
   a restart, confirm the running binary is the built artifact. Then wait for
   the user's confirmation that a real turn with tool use works through the
   deployed service, on any configured credential. The turn proves the
   deployment path, so its credential must not be one specific provider. Until
   then, deployment is awaiting verification, not landed. On failure, report
   the error and service state; do not publish.

6. **Publish.** Recheck that the candidate and destination have not changed;
   otherwise integrate and repeat affected checks, deployment, and confirmation.
   Fast-forward the fork with `git push origin HEAD:main`. Verify the remote
   SHA equals the tested commit and the running binary matches the built
   artifact. Report the commit and verification results, or the blocker.
