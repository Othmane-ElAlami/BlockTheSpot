<center>
	<h1 align="center">BlockTheSpot + Spicetify Installer</h1> 
	<h4 align="center">An automated installer for BlockTheSpot and Spicetify on <strong>Spotify for Windows (64 bit)</strong> </h4>
</center>

## Features

* Installs the necessary BlockTheSpot patches
* Installs Spicetify and the Spicetify marketplace
* Blocks ads and unlocks most premium features
* Features automatic Spotify client updates through the installation script

> [!WARNING]
> This mod is for the [**Desktop Application**](https://www.spotify.com/download/windows/) of Spotify on Windows only and **not the Microsoft Store version**.

## Installation

You can install this mod by simply downloading and running the [install.bat](https://raw.githack.com/Othmane-ElAlami/BlockTheSpot/master/install.bat) file.

Alternatively, you can run the fully automated installation via PowerShell:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-Expression "& { $(Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/Othmane-ElAlami/BlockTheSpot/master/install.ps1') } -UninstallSpotifyStoreEdition"
```

## Uninstallation

If you wish to completely restore Spotify to its original state, download and run the [uninstall.bat](https://raw.githack.com/Othmane-ElAlami/BlockTheSpot/master/uninstall.bat) script.

This will restore Spicetify settings, remove the Spicetify directories (`%APPDATA%\spicetify` and `%LOCALAPPDATA%\spicetify`), and delete `dpapi.dll` and `config.ini` from the Spotify directory.

### Disabling Automatic Updates

The automatic update feature is enabled by default. To disable it:

1. Navigate to the directory where Spotify is installed: `%APPDATA%\Spotify`.
2. Open the `config.ini` file.
3. Set `Enable_Auto_Update` to `0` under the `[Config]` section.
4. Save your changes and close the file.

Automatic updates will now be disabled. If you wish to update, you'll need to do so manually.
