# AGENTS.md

Lull is a macOS menu bar app that tells you whether it's safe to leave your Mac running
overnight on the charger. See `PLAN.md` for the design.

## Building, running and testing

- **Always use XcodeBuildMCP** (the MCP tools or the `xcodebuildmcp` CLI) to build, run,
  test, clean and inspect the project. Never call `xcodebuild` directly.
- Project path, scheme and enabled workflows come from `.xcodebuildmcp/config.yaml`. Rely
  on it instead of passing or guessing them. It is committed to the repo; keep it there.
- Do not run XcodeBuildMCP setup; the config already exists.
- If XcodeBuildMCP is not installed, **stop**. Do not fall back to `xcodebuild`. Tell the
  user it is missing, that they should install it, and then run `xcodebuildmcp init`.
