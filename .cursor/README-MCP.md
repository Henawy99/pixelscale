lay# Supabase MCP (PixelScale)

Supabase MCP is configured so Cursor can run SQL and manage the shared Supabase project for all PixelScale apps.

## Config

- **File:** `.cursor/mcp.json`
- **Server:** `https://mcp.supabase.com/mcp?project_ref=hdmycuncdlbefiiwlrca` (project-scoped to the PixelScale Supabase project)

## First-time setup

1. Open Cursor with the **pixelscale** folder as the workspace.
2. Use a chat or feature that triggers the Supabase MCP (e.g. ask to “list tables” or “run this SQL”).
3. When prompted, **log in to Supabase** (browser OAuth). Choose the organization that contains the project.
4. In Cursor: **Settings → Cursor Settings → Tools & MCP** and confirm “supabase” is listed and connected.
5. If the server does not appear, restart Cursor after signing in.

## Options

- **Read-only:** To allow only read-only SQL, change the URL in `mcp.json` to add `&read_only=true`.
- **Project ref** is already set so the MCP only sees this project (not other Supabase projects in your account).
