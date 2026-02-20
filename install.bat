@echo off
echo ========================================
echo  BlockTheSpot + Spicetify Installer
echo ========================================
echo.

echo Installing BlockTheSpot with Spicetify...
powershell -ExecutionPolicy Bypass -Command ^
    "$tempFile = [System.IO.Path]::GetTempFileName() + '.ps1'; " ^
    "(Invoke-WebRequest 'https://raw.githubusercontent.com/Othmane-ElAlami/BlockTheSpot/master/install.ps1' -UseBasicParsing).Content | Out-File $tempFile -Encoding UTF8; " ^
    "try { & $tempFile } finally { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }"
echo.
echo Installation completed. Press any key to exit...
pause
