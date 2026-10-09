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

1. **Check the control channel.** Establish that this session's provider does
   not use the proxy being redeployed. A model name alone is not proof. If the
   route is unknown, ask the user to confirm or switch to an independent
   provider before touching the service.

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
   - For service changes: `sh -n contrib/systemd/cliproxyapi`,
     `shellcheck contrib/systemd/cliproxyapi`, and
     `systemd-analyze --user verify contrib/systemd/cliproxyapi.service`.
     Parse the YAML and exercise key substitution with a dummy key and binary.
   - `go build -o cli-proxy-api ./cmd/server` for the deployment artifact.
   Require every applicable local check, remote check, and review to pass for
   this exact candidate. Pending, missing, or unverifiable requirements block
   landing; do not bypass destination protections.
   Sources: `go.mod`, `cmd/server/main.go`, `.github/workflows/pr-test-build.yml`,
   `AGENTS.md`, and `contrib/systemd/cliproxyapi{,.service}`.

4. **Deploy.** Stop `cliproxyapi.service` with `systemctl --user`. Install the
   built binary at `~/.local/share/cliproxyapi/cli-proxy-api`, and deploy the
   repository wrapper, unit, and config to their documented user-local paths.
   Respect configured path overrides and preserve unrelated local settings.
   Reuse the existing client-key file and OAuth directory: never regenerate,
   print, or commit credentials. Do not rerun the README's key-generation step.
   Run `systemctl --user daemon-reload` and
   `systemctl --user restart cliproxyapi.service`.
   Sources: `contrib/systemd/README.md`, `contrib/systemd/cliproxyapi`,
   `contrib/systemd/cliproxyapi.service`, `contrib/systemd/config.example.yaml`.

5. **Confirm it works.** Check the service is active, remains loopback-only,
   rejects unauthenticated requests, and returns Claude models from authenticated
   `GET /v1/models`. Then wait for the user's confirmation that a real Claude
   turn with tool use works. Until then, deployment is awaiting verification,
   not landed. On failure, report the error and service state; do not publish.

6. **Publish.** Recheck that the candidate and destination have not changed;
   otherwise integrate and repeat affected checks, deployment, and confirmation.
   Fast-forward the fork with `git push origin HEAD:main`. Verify the remote
   SHA equals the tested commit and the running binary matches the built
   artifact. Report the commit and verification results, or the blocker.
