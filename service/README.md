# Workbench private data service

Python 3 standard-library HTTP service for action snapshots, Mac/phone metric uploads, optional Linux/Windows collection, daily-information reads, and authenticated Android update downloads. No runtime credentials or household configuration are included.

## Start locally

Copy `config.example.json` to a private configuration outside the checkout. Replace all four token placeholders with distinct random values (`python3 -c "import secrets; print(secrets.token_urlsafe(32))"`), set an absolute `stateDirectory` for your account, and restrict the configuration to mode 0600. The state directory holds private data and is not a source or publication directory.

```
python3 server.py --config /path/to/private/config.json
```

The example binds loopback and starts no collectors or outbound connections. To serve an existing encrypted private network, set its actual local bind address and `allowPrivateBind: true`; wildcard, multicast and public IP binds are rejected. The service uses bearer authentication over HTTP and is intended for an already encrypted private link; it does not set up TLS, firewall rules, tunnels or a public deployment.

Roles are independent: `readToken` reads all GET endpoints; `actionsToken` writes `/v1/actions`; `macToken` writes `/v1/mac`; `phoneToken` writes `/v1/phone`. Do not put tokens in URLs, source files or public reports. `/v1/health`, `/v1/actions`, `/v1/telemetry`, `/v1/information`, and `/v1/app-updates/android` require the read role. Empty or wrong roles are rejected. `/v1/information` reads the private state's `information.json`; this service does not collect or generate the daily report.

Action packets use schemaVersion 1, SHA256 revisions, a timezone-bearing generatedAt, stable item IDs, mutually exclusive current classifications and matching group counts. Invalid or older snapshots do not replace a valid copy. The optional `activityEvidence` uses the source workflow's Chinese action labels and +08:00 progress timestamps; its 48-hour calculation does not create progress. Metric timestamps use Apple Foundation seconds (Unix seconds minus 978307200). Stale hardware and missing network evidence remain visible as stale or unknown.

## Optional collectors

Set `linux.enabled` to true only on Linux. CPU, memory, GPU availability, selected filesystem mounts and default-route traffic come from `/proc` and `/sys`. Set `linux.mounts` to your desired mount points; set `linux.lanInterface` to your actual physical LAN interface. If unspecified, LAN evidence remains unknown. Optional `linux.hostUnits` entries are `["unit-name.service", false]` for system units or `true` for user units. The service reads their current state; it does not start or stop units.

For Windows, create and verify your own OpenSSH config alias and host key first, then set `windows.enabled: true` and `windows.sshAlias` to that alias. The collector requires PowerShell 7 and existing SSH access; it uses BatchMode and StrictHostKeyChecking, never accepts a new key automatically, and inherits the user's existing SSH key/known-hosts management. `windows_telemetry.ps1` emits counters over the connection and ends its own matching sampler/lease when replaced or disconnected. It does not install a Windows service. No default SSH destination, key, port, account or known-hosts file is supplied.

Optional `linux.peerAddresses` maps `mac`/`phone` to your private-network addresses for passive Tailscale LAN observations. LAN positives require current prefixes, direct kernel route evidence and same-endpoint received-byte growth; online status alone is insufficient.

## Gateway and route adapters

The original deployment's gateway commands and device inventory are deliberately replaced by opt-in adapters. With no adapter, gateway/controller/path information is unknown; local metrics and API endpoints still work. There is no fixed gateway SSH command or bundled gateway configuration.

`gatewayAdapter.command` is an argv array for an operator-supplied **read-only** program. It runs with a five-second timeout and returns one JSON object (maximum 1 MiB), without stderr or raw output being published. The program is responsible for securely reading its own source, retaining any network credentials locally, and returning only this status contract:

```json
{
  "metadata": {
    "services": [],
    "dnsListening": false,
    "proxyListening": false,
    "lanPrefixes": [],
    "privatePeers": {},
    "gatewaySelf": {},
    "lanInterfaceUp": null
  },
  "controller": {}
}
```

`services` must match the configured `gatewayAdapter.serviceNames` and use active/inactive states. Missing controller data is shown as unavailable. Optional controller JSON is a Mihomo-compatible `/proxies` response used only to derive the configured `proxyGroup`'s selected nodes and existing test history; no controller URL, authentication, node credentials or automatic network mutation is provided. Each privatePeers entry keyed by mac/phone/winpc/linux may contain online, active, endpoint, relay, peerRelay, rxBytes, txBytes, lanRouteDirect and tailnetAddress; gatewaySelf may contain online/active/tailnetAddress. Route and prefix facts must be measured by the adapter, not inferred from an address being private.

Active path probes are off by default (`pathProbes.peers` and `command` are empty). If explicitly configured, `pathProbes.command` receives a validated configured IP as its final argument and must output official Tailscale `pong from ...` lines from the declared gateway observation point. `routeContextCommand` optionally receives the measured endpoint IP and returns `{"prefixes": [], "direct": false}` based on actual gateway kernel routes. No shell interpolation is used. Probes run serially at least 30 seconds apart per configured peer; real evidence expires after 45 seconds. Timeouts/failures invalidate the old positive path. The service never changes routes, Tailscale, DNS, firewall or proxy settings.

These deployment-specific adapters are external integration points, not complete portable gateway setup. They were not exercised against another user's real network for this release.

## Android updates

`publish_android.py --apk /path/to/app.apk --metadata /path/to/reviewed.json --release-dir /path/to/private-state/app-releases/android` atomically publishes an administrator-reviewed package. Metadata requires packageName, versionCode, versionName and certSHA256; include sha256 and size when available. First publication pins package/certificate, subsequent releases reject downgrade or replacement bytes under the same version code. Use official Android tools to verify manifest and signature before publishing: this Python utility checks ZIP structure, byte hashes and metadata consistency, not cryptographic APK signatures. The HTTP service has no package-upload endpoint. Clients must check bytes, package, version and signature and use the OS install confirmation.

## Checks and limits

```
python3 -m unittest discover -s service -p 'test_*.py'
```

Run that command from the repository root. Tests cover packet validation, authorization, action expiry, stale/unknown links, route evidence, information reads and update integrity using synthetic fixtures. This release also checks explicit collector opt-in and a local loopback startup. It does not claim live Linux/Windows/gateway deployment, Android installation or long-term operation in a new environment.
