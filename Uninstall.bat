@echo off
echo ========================================
echo  BlockTheSpot + Spicetify Uninstaller
echo ========================================
echo.

set /p UserInput="Do you want to continue with uninstallation? (y/n): "
if /i "%UserInput%"=="y" (
    echo.
    echo Stopping Spotify processes...
    taskkill /F /IM "Spotify.exe" /T >NUL 2>&1
    timeout /t 2 /nobreak >NUL
    
    echo Restoring Spicetify and removing its files...
    powershell -ExecutionPolicy Bypass -Command "spicetify restore; rmdir -r -fo $env:APPDATA\spicetify -ErrorAction SilentlyContinue; rmdir -r -fo $env:LOCALAPPDATA\spicetify -ErrorAction SilentlyContinue"
    echo - Removed Spicetify

    echo Removing BlockTheSpot files...
    if exist "%APPDATA%\Spotify\blockthespot.dll" (
        del /q "%APPDATA%\Spotify\blockthespot.dll" >NUL 2>&1
        echo - Removed blockthespot.dll
    )
    
    if exist "%APPDATA%\Spotify\chrome_elf.dll" (
        del /q "%APPDATA%\Spotify\chrome_elf.dll" >NUL 2>&1
        echo - Removed patched chrome_elf.dll
    )
    
    if exist "%APPDATA%\Spotify\chrome_elf_required.dll" (
        ren "%APPDATA%\Spotify\chrome_elf_required.dll" "chrome_elf.dll" >NUL 2>&1
        echo - Restored original chrome_elf.dll
    )
    
    if exist "%APPDATA%\Spotify\config.ini" (
        del /q "%APPDATA%\Spotify\config.ini" >NUL 2>&1
        echo - Removed config.ini
    ) else (
        echo - config.ini not found
    )
    
    if exist "%APPDATA%\Spotify\blockthespot_settings.json" (
        del /q "%APPDATA%\Spotify\blockthespot_settings.json" >NUL 2>&1
        echo - Removed blockthespot_settings.json
    ) else (
        echo - blockthespot_settings.json not found
    )
    
    echo.
    echo Uninstallation completed!
    echo You can now use Spotify normally.
    echo.
) else (
    echo.
    echo Uninstallation cancelled.
)
pause