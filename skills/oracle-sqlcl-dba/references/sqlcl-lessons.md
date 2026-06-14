## SQLcl Connections

- Saved connections live in `~/.dbtools/connections/<uuid>/credentials.sso`.
- These are **not portable** between servers – encryption key is tied to local OS user.
- To move connections between servers: use **Oracle Wallet** (`orapki` + `mkstore`) instead.

## conn Syntax

- Use `@//host:port/service`, **not** `@host:port/service` (missing `//` makes it look like a TNS alias).
- `-save` + `-savepwd` together are the way to persist credentials.

## MCP Config

- MCP servers go in `~/.hermes/config.yaml` under `mcp_servers:`.
- They activate at Hermes agent start, not just interactive chat. Gateway restart required after config changes.
- For SQLcl MCP: `sql -mcp` needs saved connections in `~/.dbtools` **before** the server starts.

## MCP Compatibility: raw `sql -mcp` vs `sql-mcp` wrapper

In this environment, plain `sql -mcp` fails with:
`Unrecognized field "tools" in ClientCapabilities$Sampling`

Use the stdio wrapper instead of raw `sql -mcp`. It patches the Hermes `initialize` request to remove unsupported `sampling.tools`/`sampling.toolChoice` fields before passing through to SQLcl.

Expected wrapper path: `/opt/sqlcl/bin/sql-mcp`

Hermes-friendly config entry:
```yaml
mcp_servers:
  oracle-sqlcl-MCP:
    command: /opt/sqlcl/bin/sql-mcp
    args: []
    env:
      JAVA_TOOL_OPTIONS: -Dfile.encoding=UTF-8
```
