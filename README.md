# acestream – Ace Stream on your TV, in one click

**English** | [Magyar](README.hu.md)

Play Ace Stream broadcasts on your smart TV over DLNA, from a Windows PC.
You don't install anything on the TV and nothing is transcoded: the TV receives the original
stream from the Ace Stream engine running on your PC.

Tested on an LG webOS TV (LG OLED65C4). Other DLNA-capable TVs (Samsung, Sony, Philips, etc.)
will probably work the same way, but I haven't tested them.

```
acestream://…  ──►  Ace Stream engine (PC, 6878)  ──►  ace_tv_proxy.py (PC, 6879)  ──►  LG TV (DLNA)
```

## What is this, and why do you need it?

Ace Stream is a P2P streaming system. The Windows **Ace Player** only plays the stream on the PC
and can't send it to a TV.

The **Ace Stream engine** running in the background, however, also serves the stream over HTTP,
and in principle a DLNA-capable TV can open it. In practice two things get in the way:

1. Something has to tell the TV what to play. `cast-to-lgtv.ps1` does this: it finds the TV on
   the network and sends it the stream URL with a DLNA (UPnP AVTransport) command.
2. Before playing, the LG TV checks the URL with an HTTP `HEAD` request. The Ace engine answers
   it with `501 Not Implemented`, so the TV never starts playback. `ace_tv_proxy.py` is a small
   proxy in front of the engine. It answers `HEAD` correctly, passes `GET` on to the engine
   (following its redirects), and returns the video with DLNA headers.

You can keep watching in Ace Player on the PC at the same time: the engine can serve the same
broadcast to several players at once.

## Requirements

| | |
|---|---|
| **Windows 10 / 11** | Finding the TV relies on Windows' built-in UPnP component. |
| **Ace Stream Media** | <https://acestream.org>. It must be running after installation (`ace_engine.exe` on port 6878). |
| **Python 3.8+** | <https://www.python.org/downloads/>. `python.exe` must be on the PATH. No extra packages needed. |
| **DLNA-capable TV** | On the same local network as the PC (cable or Wi-Fi). |

Nothing needs to be installed on the TV. DLNA playback is enabled by default on LG TVs.

## Installation

```powershell
git clone https://github.com/mp3pintyo/acestream.git
cd acestream
```

(or download it as a ZIP and extract it to a folder)

**Firewall:** on first run Windows may ask whether Python may accept connections from the
network. Allow it for the network type your PC is on. If your network is *Public*, tick that
too, otherwise the TV can't reach the proxy. The Ace Stream installer already creates a
firewall rule for the engine itself.

## Usage

> The scripts' console messages are in Hungarian. The commands and parameters below work the same regardless.

### The easy way: double-click

1. Start Ace Stream (or Ace Player) on the PC and turn on the TV.
2. Double-click **`Ace a TV-re.cmd`** ("Ace to the TV").
3. Paste the `acestream://...` link (or just the 40-character ID) and press Enter.
4. After a few seconds of buffering the broadcast starts on the TV.

You can also pass a parameter:

```bat
"Ace a TV-re.cmd" acestream://0123456789abcdef0123456789abcdef01234567
"Ace a TV-re.cmd" stop
```

### From PowerShell

```powershell
# Send a broadcast to the TV
.\cast-to-lgtv.ps1 acestream://0123456789abcdef0123456789abcdef01234567

# List the DLNA players found on the network
.\cast-to-lgtv.ps1 -List

# With several TVs / players, pick one by name
.\cast-to-lgtv.ps1 <ID> -TvName "OLED"

# Stop playback on the TV
.\cast-to-lgtv.ps1 -Stop
```

If PowerShell won't run the script:
`powershell -ExecutionPolicy Bypass -File .\cast-to-lgtv.ps1 <ID>`

To switch channels, just send the new link. The TV stops the previous broadcast and starts the
new one.

## Files

| File | What it does |
|---|---|
| `Ace a TV-re.cmd` | Double-click launcher. Asks for the link and calls the PowerShell script. |
| `cast-to-lgtv.ps1` | Finds the TV, checks that the Ace engine is running, starts the proxy if needed (in a hidden window), then sends the stream to the TV over DLNA. |
| `ace_tv_proxy.py` | HTTP proxy on port 6879. Forwards requests for `http://<PC-IP>:6879/ace/<ID>.ts` to the Ace engine. Uses only the Python standard library. |

## How it works in detail

1. `cast-to-lgtv.ps1` uses Windows' `UPnP.UPnPDeviceFinder` COM object to find `MediaRenderer`
   devices on the network. If there's an LG, it picks that one.
2. It checks that the Ace Stream engine is running (`http://127.0.0.1:6878`).
3. If nothing is listening on port 6879 yet, it starts the proxy.
4. It hands the TV the URL `http://<PC-IP>:6879/ace/<ID>.ts` with `SetAVTransportURI`
   (with DIDL-Lite metadata, type `video/mp2t`), then sends `Play`.
5. The TV calls the proxy. The proxy requests the broadcast from the Ace engine at
   `/ace/getstream?id=<ID>&pid=<random>`. The random `pid` gives the TV its own playback session,
   so it works alongside Ace Player on the PC.
6. The engine delivers the stream as MPEG-TS (e.g. H.264 video + AC3 audio), and the proxy
   passes it through unchanged. There's no transcoding, so it puts no load on the PC.

## Troubleshooting

**"Nem talalok TV-t a halozaton" (TV not found on the network)**
Turn the TV fully on (standby isn't enough) and check that it's on the same network.
`.\cast-to-lgtv.ps1 -List` shows what the PC can see.

**"Az Ace Stream motor nem fut" (Ace Stream engine not running)**
Start Ace Stream. It's enough if its icon is in the system tray.

**Nothing happens on the TV, or it keeps loading**
- The firewall is most likely blocking Python. Under *Windows Defender Firewall → Allow an app*,
  check that `python.exe` is allowed on your network type (Public / Private).
- Check that the broadcast itself is live: open the link in Ace Player on the PC.
- Send it again: sometimes the TV gets "stuck" on the first attempt.

**The picture freezes on the TV**
It's a P2P stream, so quality depends on the source and the other viewers. If it stutters in Ace
Player, it will stutter on the TV too.

**How do I stop the proxy running in the background?**
The proxy keeps running in a hidden window until you sign out of Windows or stop it:

```powershell
Get-CimInstance Win32_Process -Filter "Name='python.exe'" |
  Where-Object CommandLine -like '*ace_tv_proxy.py*' |
  ForEach-Object { Stop-Process -Id $_.ProcessId }
```

## Tested TVs and related project

- **LG OLED65C4** (webOS): the TV this project was built on.
- **Philips 58PUS7805/12** (2020, Saphi): `cast-to-lgtv.ps1 -List` finds it, and an MPEG-TS stream
  (H.264 + AAC test video) pushed over DLNA plays. Worth knowing:
  - it sends no `HEAD` request, only several short probing `GET`s before playback;
  - while the previous stream is still playing, `SetAVTransportURI` returns `705 Transport locked`
    for a few seconds, so wait a moment after Stop or simply send it again.
- **[Fájl a TV-re](https://github.com/rknoise/fajl-a-tv-re)**: a small GUI built on the same DLNA approach
  for *local video files* (MP4 / MKV / AVI), with on-the-fly ffmpeg conversion when needed and seeking.

## Limitations

- Windows only (finding the TV uses a Windows COM object; the proxy itself would run anywhere).
- Only tested on an LG webOS TV.
- The PC and the Ace Stream engine must keep running, because the TV gets the stream from the PC.

## Legal notice

This project is just a network helper that lets you watch what the Ace Stream engine on your own
PC is playing on your own TV. It contains and recommends no broadcasts or links.
What you watch, and whether you have the right to watch it, is your responsibility.

Ace Stream is a product of the Ace Stream developers. This project is not affiliated with them.

## License

MIT – see [LICENSE](LICENSE).
