@echo off
setlocal enabledelayedexpansion

for /f "usebackq tokens=1,2 delims==" %%A in (".env") do (
    if not "%%A"=="" (
        set "%%A=%%B"
    )
)

copy /Y android\app\google-services.json.template android\app\google-services.json
for /f "usebackq tokens=1,2 delims==" %%A in (".env") do (
    if not "%%A"=="" (
        powershell -Command "(Get-Content android\app\google-services.json) -replace '\$\{%%A\}', '%%B' | Set-Content android\app\google-services.json"
    )
)

copy /Y android\app\src\main\AndroidManifest.xml.template android\app\src\main\AndroidManifest.xml
for /f "usebackq tokens=1,2 delims==" %%A in (".env") do (
    if not "%%A"=="" (
        powershell -Command "(Get-Content android\app\src\main\AndroidManifest.xml) -replace '\$\{%%A\}', '%%B' | Set-Content android\app\src\main\AndroidManifest.xml"
    )
)

echo Đã sinh file google-services.json và AndroidManifest.xml từ template!
pause
