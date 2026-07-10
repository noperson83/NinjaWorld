# Roblox Studio MCP repair

This repo does not need Rojo for the current MCP fix. Rojo is a source-sync/build tool; MCP is the bridge that lets a connected agent talk to Roblox Studio. If the goal is to get Studio MCP working again, focus on the MCP launcher first.

## Problem seen on the PC

Running:

```bat
cmd /k "%LOCALAPPDATA%\Roblox\mcp.bat"
```

printed errors like:

```text
'else' is not recognized as an internal or external command
'"%B/..\StudioMCP.exe"' is not recognized as an internal or external command
```

That usually means `%LOCALAPPDATA%\Roblox\mcp.bat` was generated for an older Roblox Studio install or got parsed badly after Studio updated.

## Repair the MCP launcher

On the Windows PC that has Roblox Studio installed, run this from the repo root:

```bat
tools\fix_roblox_studio_mcp.bat
```

The repair script searches:

```text
%LOCALAPPDATA%\Roblox\Versions\
```

for the newest `StudioMCP.exe`, then rewrites:

```text
%LOCALAPPDATA%\Roblox\mcp.bat
```

as a simpler launcher that points directly at the current `StudioMCP.exe`.

## Test it

After the repair, run:

```bat
cmd /k "%LOCALAPPDATA%\Roblox\mcp.bat"
```

If it stays open without the old `else` / `%B` errors, reopen Roblox Studio and reconnect the MCP client.

## If it still fails

1. Open Roblox Studio once so it updates its `Versions` folder.
2. Rerun:
   ```bat
   tools\fix_roblox_studio_mcp.bat
   ```
3. Test again:
   ```bat
   cmd /k "%LOCALAPPDATA%\Roblox\mcp.bat"
   ```
4. If it says `StudioMCP.exe` cannot be found, Roblox Studio may need to be updated or reinstalled.
