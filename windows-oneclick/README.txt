OmniRoute OneClick for Windows - ChrisCompton fork

1. Stop the old OmniRoute PowerShell window with Ctrl+C.
2. Extract ALL files from this ZIP into a normal folder.
3. Double-click Setup.cmd. Do not run as administrator.
4. Wait for installation/build. First setup can take several minutes.
5. The browser opens after /login responds. Keep the server window open.
6. Next time, double-click the Start OmniRoute desktop shortcut.

What it does:
- Reuses C:\Users\YOURNAME\OmniRoute-Chris when already present.
- Otherwise downloads ChrisCompton/omniroute at commit
  515674b6cf7cc29b3db027c9119e9b2ef12e0ba7 (not a continuously changing branch).
- Uses portable official Node.js 22.23.4 in your Tools folder. If it downloads
  Node, verifies its SHA256 against nodejs.org's SHASUMS256.txt.
- Uses the existing project data folder, .env and API connections.
- Removes only blank secret assignments from .env, keeping a backup, so the
  project's persisted server.env secrets can load correctly.
- Renames root app artifacts to a backup so src/app routes are used.
- Builds production pages once. Start uses npm run start, never dev mode.
- Installs launchers under %LOCALAPPDATA%\OmniRouteLauncher.
- Opens http://localhost:20130/dashboard. Stop with Ctrl+C.
- Does not stop other processes or overwrite an occupied port.

Login:
Existing installations retain their existing password. If you never changed
the default, it may still be CHANGEME; change it in the dashboard Settings.
Fresh installations get a random password saved in
%LOCALAPPDATA%\OmniRouteLauncher\LOGIN.txt. Keep that file private.

OpenRouter's API key still needs to be entered in Providers > OpenRouter.
Claude Desktop needs its own gateway setup using an OmniRoute-generated API key.
This launcher does not grant paid model access or remove free-tier quotas.

ExecutionPolicy Bypass applies only to the child PowerShell process running
these local scripts; it does not change the machine/user execution policy.

Source: https://github.com/ChrisCompton/omniroute
This is a convenience launcher, not an official upstream installer.
Windows end-to-end installation was not run in this Linux workspace.
If npm install/build fails, Setup stops and keeps the error visible. Send the
error text for diagnosis. Do not run npm audit fix --force as a setup step.
