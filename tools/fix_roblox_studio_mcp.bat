@echo off
setlocal EnableExtensions

rem Repairs the Roblox Studio MCP launcher at %LOCALAPPDATA%\Roblox\mcp.bat.
rem The generated launcher avoids fragile IF (...) ELSE (...) parsing so it keeps
rem working after Roblox Studio updates its version-* folder.

set "ROBLOX_DIR=%LOCALAPPDATA%\Roblox"
set "VERSIONS_DIR=%ROBLOX_DIR%\Versions"
set "TARGET=%ROBLOX_DIR%\mcp.bat"
set "STUDIO_MCP="

if not exist "%VERSIONS_DIR%" goto :missing_versions

for /f "delims=" %%F in ('dir /b /s /a:-d /o:-d "%VERSIONS_DIR%\StudioMCP.exe" 2^>nul') do (
    set "STUDIO_MCP=%%F"
    goto :found_studio_mcp
)

goto :missing_studio_mcp

:found_studio_mcp
> "%TARGET%" echo @echo off
>> "%TARGET%" echo setlocal EnableExtensions
>> "%TARGET%" echo set "STUDIO_MCP=%STUDIO_MCP%"
>> "%TARGET%" echo if not exist "%%STUDIO_MCP%%" goto :missing_studio_mcp
>> "%TARGET%" echo "%%STUDIO_MCP%%" %%*
>> "%TARGET%" echo exit /b %%ERRORLEVEL%%
>> "%TARGET%" echo :missing_studio_mcp
>> "%TARGET%" echo echo StudioMCP.exe was not found at "%%STUDIO_MCP%%" 1^>^&2
>> "%TARGET%" echo echo Open Roblox Studio once, then rerun tools\fix_roblox_studio_mcp.bat from this repo. 1^>^&2
>> "%TARGET%" echo exit /b 1

echo Repaired "%TARGET%"
echo Using "%STUDIO_MCP%"
echo.
echo Test it with:
echo   cmd /k "%%LOCALAPPDATA%%\Roblox\mcp.bat"
exit /b 0

:missing_versions
echo Could not find Roblox Versions folder: "%VERSIONS_DIR%" 1>&2
echo Open or reinstall Roblox Studio, then run this repair script again. 1>&2
exit /b 1

:missing_studio_mcp
echo Could not find StudioMCP.exe under "%VERSIONS_DIR%" 1>&2
echo Open/update Roblox Studio, then run this repair script again. 1>&2
exit /b 1
