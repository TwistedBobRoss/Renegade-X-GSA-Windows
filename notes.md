# Renegade X GSA Windows Draft Notes

This draft is based on the inspected archive:

`C:\Users\imgon\Downloads\renegade_x_Release_1.0.1022_3.zip`

Observed server-relevant files:

- `Binaries\Win64\UDK.exe`
- `UDKGame\Config\DefaultGame.ini`
- `UDKGame\Config\DefaultEngine.ini`
- `UDKGame\Config\DefaultMapList.ini`
- `UDKGame\Config\DefaultRenegadeX.ini`
- `UDKGame\Config\DefaultWeb.ini`
- `UDKGame\CookedPC`

The Totem Wiki documents runtime config names instead of only default config names:

- `UDKGame\Config\UDKGame.ini`
- `UDKGame\Config\UDKEngine.ini`
- `UDKGame\Config\UDKRenegadeX.ini`
- `UDKGame\Config\UDKWeb.ini`

Observed default ports/settings:

- Game port: `7777`
- Peer port: `7778`
- Query port: `27015`
- Web port: `6969`
- RCON is enabled in `DefaultRenegadeX.ini`
- RCON port defaults to `-1`
- RCON logging is enabled with `bLogRcon=true`

Confirmed dedicated launch pattern from Totem forum/wiki examples:

```bat
UDK.exe server CNC-Field?maxplayers=64 -port=7777
UDK.exe server CNC-Field?NODBotCount=8?GDIBotCount=8
UDK.exe server CNC-Field -MULTIHOME=192.168.1.96
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

Custom content notes:

- Totem Wiki `Downloads` page says clients download loaded packages from the server or from HTTP redirect.
- Channel download uses `UDKEngine.ini` `[IpDrv.TcpNetDriver] AllowDownloads=True`.
- HTTP redirect uses `UDKEngine.ini` `[IpDrv.HTTPDownload] RedirectToURL=` and `UseCompression=`.
- HTTP redirect files must be flat at the web root, URL needs a trailing slash, and the webserver normally must run on port 80.
- Mutators load by command line with `?mutator=Package.Class,Package.OtherClass`.
- Mutator `.u` packages belong under `UDKGame\CookedPC`; map `.udk` files belong under `UDKGame\CookedPC\Maps\RenX`.
