@echo off
echo ========================================
echo  BlockTheSpot + Spicetify Installer
echo ========================================
echo.

set /p UserInput="Spicetify will be installed. If you don't agree, use the BlockTheSpot script. Do you want to continue with the installation? (y/n): "
if /i "%UserInput%"=="y" (
    echo.
    echo Installing BlockTheSpot with Spicetify...
    powershell -ExecutionPolicy Bypass -Command ^
        "$tempFile = [System.IO.Path]::GetTempFileName() + '.ps1'; " ^
        "(Invoke-WebRequest 'https://raw.githubusercontent.com/mrpond/BlockTheSpot/master/install.ps1' -UseBasicParsing).Content | Out-File $tempFile -Encoding UTF8; " ^
        "try { & $tempFile -InstallSpicetify } finally { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }"
    echo.
    echo Installation completed. Press any key to exit...
    pause
) else (
    echo.
    echo Installation cancelled.
    pause
    exit /b
)
