# Renegade X GSA Windows Draft Notes

This draft is based on the inspected archive:

`C:\Users\imgon\Downloads\renegade_x_Release_1.0.1022_3.zip`

Observed server-relevant files:

- `Binaries\Win64\UDK.exe`
- `Binaries\Win32\UDK.exe`
- `UDKGame\Config\DefaultGame.ini`
- `UDKGame\Config\DefaultEngine.ini`
- `UDKGame\Config\DefaultMapList.ini`
- `UDKGame\Config\DefaultRenegadeX.ini`
- `UDKGame\Config\DefaultWeb.ini`

Observed default ports/settings:

- Game port: `7777`
- Peer port: `7778`
- Query port: `27015`
- Web port: `6969`
- RCON is enabled in `DefaultRenegadeX.ini`
- RCON port defaults to `-1`
- RCON logging is enabled with `bLogRcon=true`

Likely dedicated launch pattern:

```bat
UDK.exe server CNC-Field?Game=RenX_Game.Rx_Game?MaxPlayers=40?Port=7777 -log=RenegadeXServer.log -unattended
```

Main game classes found:

- `RenX_Game.Rx_Game` for standard Command & Conquer maps
- `RenX_Coop.Rx_Game_Survival` for Defense Survival maps
- `TibSun_Game.TS_Game_Conquest` appears in config, but no `CQ-*` maps were present in the inspected archive

Good first GSA dropdown candidates:

- Map
- Game class
- Max players preset
- RCON enabled
- Public/private password behavior
- Map vote behavior
- Fixed rotation

Good text-field candidates:

- Server name
- Admin password
- Server password
- Extra launch args
- Custom map name
- Custom map rotation
