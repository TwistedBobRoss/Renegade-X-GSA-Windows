FROM mcr.microsoft.com/windows/servercore:ltsc2022

SHELL ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]

WORKDIR C:/serverfiles

COPY renx_payload/ C:/serverfiles/
COPY Start.ps1 C:/serverfiles/Start.ps1
COPY LaunchRenegadeXServer.bat C:/serverfiles/LaunchRenegadeXServer.bat

RUN if (-not (Test-Path 'C:/serverfiles/Binaries/Win64/UDK.exe')) { throw 'Renegade X Win64 UDK.exe not found in image payload'; }; \
    New-Item -ItemType Directory -Force -Path C:/renx-data/Config, C:/renx-data/CustomContent, C:/renx-data/Logs | Out-Null

EXPOSE 7777/udp
EXPOSE 7778/udp
EXPOSE 27015/udp
EXPOSE 37015/tcp
EXPOSE 6969/tcp

ENV RENX_ROOT=C:\serverfiles
ENV RENX_DATA_ROOT=C:\renx-data

ENTRYPOINT ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "C:/serverfiles/Start.ps1"]
