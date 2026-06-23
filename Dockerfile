# escape=`
FROM mcr.microsoft.com/windows/server:ltsc2022

SHELL ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]

WORKDIR C:/renx-bootstrap

COPY Start.ps1 C:/renx-bootstrap/Start.ps1
COPY RunRenX.ps1 C:/renx-bootstrap/RunRenX.ps1
COPY LaunchRenegadeXServer.bat C:/renx-bootstrap/LaunchRenegadeXServer.bat

ARG VC2010_X64_URL=https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x64.exe
ARG VC2010_X64_SHA256=F3B7A76D84D23F91957AA18456A14B4E90609E4CE8194C5653384ED38DADA6F3
ARG VC2015_X64_URL=https://download.visualstudio.microsoft.com/download/pr/285b28c7-3cf9-47fb-9be8-01cf5323a8df/8F9FB1B3CFE6E5092CF1225ECD6659DAB7CE50B8BF935CB79BFEDE1F3C895240/VC_redist.x64.exe
ARG VC2015_X64_SHA256=8F9FB1B3CFE6E5092CF1225ECD6659DAB7CE50B8BF935CB79BFEDE1F3C895240
ARG DIRECTX_JUNE2010_URL=https://download.microsoft.com/download/8/4/a/84a35bf1-dafe-4ae8-82af-ad2ae20b6b14/directx_Jun2010_redist.exe

RUN $ErrorActionPreference = 'Stop'; `
    New-Item -ItemType Directory -Force -Path C:/renx-runtime-install, C:/renx-runtime-install/directx | Out-Null; `
    Invoke-WebRequest -Uri $env:VC2010_X64_URL -OutFile C:/renx-runtime-install/vcredist_x64.exe -UseBasicParsing; `
    $vcHash = (Get-FileHash -Algorithm SHA256 -LiteralPath C:/renx-runtime-install/vcredist_x64.exe).Hash; `
    if ($vcHash -ne $env:VC2010_X64_SHA256) { throw ('Visual C++ 2010 x64 installer hash mismatch: {0}' -f $vcHash) }; `
    $vc = Start-Process C:/renx-runtime-install/vcredist_x64.exe -ArgumentList '/quiet','/norestart' -Wait -PassThru; `
    Write-Host ('Visual C++ 2010 x64 installer exit code: {0}' -f $vc.ExitCode); `
    if ($vc.ExitCode -notin 0, 1638, 3010) { throw ('Visual C++ 2010 x64 installation failed with exit code {0}' -f $vc.ExitCode) }; `
    $vcRuntimeRoots = @(Get-ChildItem C:/Windows/WinSxS -Directory -Filter 'amd64_microsoft.vc100.crt_*' -ErrorAction SilentlyContinue); `
    foreach ($dllName in @('MSVCP100.dll','MSVCR100.dll')) { `
        $target = Join-Path C:/Windows/System32 $dllName; `
        if (-not (Test-Path -LiteralPath $target)) { `
            $candidate = $vcRuntimeRoots | ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Filter $dllName -File -ErrorAction SilentlyContinue } | Select-Object -First 1; `
            if (-not $candidate) { throw ('Visual C++ 2010 runtime DLL was not installed: {0}' -f $dllName) }; `
            Copy-Item -LiteralPath $candidate.FullName -Destination $target -Force `
        }; `
        Write-Host ('Installed Visual C++ runtime DLL: {0}' -f $dllName) `
    }; `
    Invoke-WebRequest -Uri $env:VC2015_X64_URL -OutFile C:/renx-runtime-install/vc_redist.x64.exe -UseBasicParsing; `
    $modernVcHash = (Get-FileHash -Algorithm SHA256 -LiteralPath C:/renx-runtime-install/vc_redist.x64.exe).Hash; `
    if ($modernVcHash -ne $env:VC2015_X64_SHA256) { throw ('Visual C++ 2015-2022 x64 installer hash mismatch: {0}' -f $modernVcHash) }; `
    $modernVc = Start-Process C:/renx-runtime-install/vc_redist.x64.exe -ArgumentList '/install','/quiet','/norestart' -Wait -PassThru; `
    Write-Host ('Visual C++ 2015-2022 x64 installer exit code: {0}' -f $modernVc.ExitCode); `
    if ($modernVc.ExitCode -notin 0, 1638, 3010) { throw ('Visual C++ 2015-2022 x64 installation failed with exit code {0}' -f $modernVc.ExitCode) }; `
    if (-not (Test-Path -LiteralPath C:/Windows/System32/VCRUNTIME140.dll)) { throw 'Visual C++ 2015-2022 runtime DLL was not installed: VCRUNTIME140.dll' }; `
    Invoke-WebRequest -Uri $env:DIRECTX_JUNE2010_URL -OutFile C:/renx-runtime-install/directx_redist.exe -UseBasicParsing; `
    $extract = Start-Process C:/renx-runtime-install/directx_redist.exe -ArgumentList '/Q','/T:C:\renx-runtime-install\directx' -Wait -PassThru; `
    Write-Host ('DirectX redist extraction exit code: {0}' -f $extract.ExitCode); `
    if ($extract.ExitCode -ne 0) { throw ('DirectX redist extraction failed with exit code {0}' -f $extract.ExitCode) }; `
    $legacyCabNames = @('Jun2010_D3DCompiler_43_x64.cab','Jun2010_d3dx9_43_x64.cab','Jun2010_d3dx11_43_x64.cab','Jun2010_XAudio_x64.cab','Feb2010_X3DAudio_x64.cab','APR2007_xinput_x64.cab'); `
    foreach ($cabName in $legacyCabNames) { `
        $cabPath = Join-Path C:/renx-runtime-install/directx $cabName; `
        if (-not (Test-Path -LiteralPath $cabPath)) { throw ('Required DirectX cabinet was not found: {0}' -f $cabName) }; `
        & expand.exe '-F:*.dll' $cabPath C:/Windows/System32 | Out-Host; `
        if ($LASTEXITCODE -ne 0) { throw ('Failed to extract DirectX cabinet {0}; expand.exe exit code {1}' -f $cabName, $LASTEXITCODE) } `
    }; `
    $requiredLegacyDlls = @('D3DCompiler_43.dll','d3dx9_43.dll','d3dx11_43.dll','XAudio2_7.dll','XAPOFX1_5.dll','X3DAudio1_7.dll','xinput1_3.dll'); `
    foreach ($dllName in $requiredLegacyDlls) { `
        if (-not (Test-Path -LiteralPath (Join-Path C:/Windows/System32 $dllName))) { throw ('Required DirectX DLL was not installed: {0}' -f $dllName) }; `
        Write-Host ('Installed legacy DirectX DLL: {0}' -f $dllName) `
    }; `
    Remove-Item C:/renx-runtime-install -Recurse -Force

RUN $parseErrors = $null; $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content -Raw -LiteralPath C:/renx-bootstrap/Start.ps1), [ref]$parseErrors); if ($parseErrors) { throw ($parseErrors | Out-String) }; $parseErrors = $null; $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content -Raw -LiteralPath C:/renx-bootstrap/RunRenX.ps1), [ref]$parseErrors); if ($parseErrors) { throw ($parseErrors | Out-String) }

RUN New-Item -ItemType Directory -Force -Path C:/renx-data/ServerFiles, C:/renx-data/Config, C:/renx-data/CustomContent, C:/renx-data/Logs, C:/renx-data/PayloadCache | Out-Null

EXPOSE 7777/udp
EXPOSE 7778/udp
EXPOSE 27015/udp
EXPOSE 37015/tcp
EXPOSE 6969/tcp

ENV RENX_BOOTSTRAP_ROOT=C:/renx-bootstrap
ENV RENX_ROOT=C:/renx-data/ServerFiles
ENV RENX_DATA_ROOT=C:/renx-data
COPY Compiler/UE3ShaderCompileWorker.exe C:/renx-data/ServerFiles/Binaries/Win64/UE3ShaderCompileWorker.exe

ENTRYPOINT ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "$launcher='C:/renx-data/ServerFiles/LaunchRenegadeXServer.bat'; New-Item -ItemType Directory -Force -Path (Split-Path -Parent $launcher) | Out-Null; Copy-Item -LiteralPath 'C:/renx-bootstrap/LaunchRenegadeXServer.bat' -Destination $launcher -Force; Write-Host \"Prepared Renegade X launcher: $launcher\"; & 'C:/renx-bootstrap/Start.ps1'; exit $LASTEXITCODE"]
