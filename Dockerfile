FROM mcr.microsoft.com/windows/servercore:ltsc2022

SHELL ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]

WORKDIR C:/renx-bootstrap

COPY Start.ps1 C:/renx-bootstrap/Start.ps1
COPY LaunchRenegadeXServer.bat C:/renx-bootstrap/LaunchRenegadeXServer.bat

RUN $parseErrors = $null; $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content -Raw -LiteralPath C:/renx-bootstrap/Start.ps1), [ref]$parseErrors); if ($parseErrors) { throw ($parseErrors | Out-String) }

RUN New-Item -ItemType Directory -Force -Path C:/renx-data/ServerFiles, C:/renx-data/Config, C:/renx-data/CustomContent, C:/renx-data/Logs, C:/renx-data/PayloadCache | Out-Null

EXPOSE 7777/udp
EXPOSE 7778/udp
EXPOSE 27015/udp
EXPOSE 37015/tcp
EXPOSE 6969/tcp

ENV RENX_BOOTSTRAP_ROOT=C:\renx-bootstrap
ENV RENX_ROOT=C:\renx-data\ServerFiles
ENV RENX_DATA_ROOT=C:\renx-data

ENTRYPOINT ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "$launcher='C:/renx-data/ServerFiles/LaunchRenegadeXServer.bat'; New-Item -ItemType Directory -Force -Path (Split-Path -Parent $launcher) | Out-Null; Copy-Item -LiteralPath 'C:/renx-bootstrap/LaunchRenegadeXServer.bat' -Destination $launcher -Force; Write-Host \"Prepared Renegade X launcher: $launcher\"; & 'C:/renx-bootstrap/Start.ps1'; exit $LASTEXITCODE"]
