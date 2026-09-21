# Third-Party Notices

Stornaut's shipped Swift packages and App bundle currently have no third-party
code or package dependencies.

Repository-only development tools are not linked, copied into, or distributed
with `Stornaut.app`:

| Tool | Version | License | Source | Development use |
| --- | --- | --- | --- | --- |
| XcodeBuildMCP | `2.7.0` | MIT | <https://github.com/getsentry/XcodeBuildMCP/tree/v2.7.0> | local Xcode/SwiftPM build, test, launch and project queries; exact npm dependency graph is recorded in `tools/xcodebuildmcp/package-lock.json` |
| Peekaboo | `3.10.0` | MIT | <https://github.com/openclaw/Peekaboo/tree/v3.10.0> | local read-only macOS runtime UI observation; downloaded on demand and integrity/signature checked |

The XcodeBuildMCP lockfile includes transitive development packages under
MIT, ISC, BSD-2-Clause, BSD-3-Clause, Apache-2.0, Unlicense and BlueOak-1.0.0.
Their package metadata and integrity hashes remain in the lockfile; installed
`node_modules` are ignored and are not release artifacts.

Before adding third-party code, packages, fixtures derived from upstream source, or bundled tools:

1. complete the applicable Upstream Study Gate;
2. record the exact source URL, commit/version, license, copyright holder, and usage;
3. confirm that the license is compatible with Stornaut's MIT distribution;
4. add required attribution or license text in this directory;
5. document why the dependency is necessary and what independent verification was performed.

Behavioral research, public facts, protocols, and clean-room test ideas do not require copying upstream code, but their provenance still belongs in `docs/upstream-studies/`.
