# acestream – Ace Stream a TV-n, egy kattintással

Ace Stream adások lejátszása a smart TV-n (DLNA-n keresztül), Windowsról.
Nem kell hozzá semmit telepíteni a TV-re, és nincs átkódolás: a TV a gépen futó
Ace Stream motortól kapja az eredeti streamet.

LG webOS TV-n tesztelve (LG OLED65C4). Más, DLNA-t támogató TV-vel (Samsung, Sony, Philips stb.)
valószínűleg ugyanígy működik, de ezt nem próbáltam ki.

```
acestream://…  ──►  Ace Stream motor (PC, 6878)  ──►  ace_tv_proxy.py (PC, 6879)  ──►  LG TV (DLNA)
```

## Mi ez, és miért kell?

Az Ace Stream egy P2P alapú streamelő rendszer. A Windowsos **Ace Player** csak a gépen
játssza le az adást, a TV-re nem tudja átküldeni.

A háttérben futó **Ace Stream motor** viszont HTTP-n is kiadja a streamet, és ezt elvileg egy
DLNA-képes TV is meg tudja nyitni. A gyakorlatban két dolog akadályozza:

1. A TV-nek meg kell mondani, mit játsszon le. Ezt a `cast-to-lgtv.ps1` intézi: megkeresi a TV-t
   a hálózaton, és DLNA (UPnP AVTransport) paranccsal ráküldi a stream címét.
2. Az LG TV lejátszás előtt egy `HEAD` kéréssel ellenőrzi az URL-t, amire az Ace motor
   `501 Not Implemented` hibát ad. Emiatt a TV el sem indítja a lejátszást. Az `ace_tv_proxy.py`
   egy kis proxy a motor előtt: a `HEAD`-re helyesen válaszol, a `GET`-et pedig továbbadja a
   motornak (az átirányításokkal együtt), és DLNA-fejlécekkel küldi tovább a videót.

A PC-n futó Ace Player közben nyugodtan mehet tovább: a motor ugyanazt az adást
egyszerre több lejátszónak is ki tudja adni.

## Mi kell hozzá?

| | |
|---|---|
| **Windows 10 / 11** | A TV-keresés a Windows beépített UPnP-komponensét használja. |
| **Ace Stream Media** | <https://acestream.org> – a telepítés után futnia kell (a `ace_engine.exe` a 6878-as porton). |
| **Python 3.8+** | <https://www.python.org/downloads/> – a `python.exe` legyen a PATH-on. Külső csomag nem kell. |
| **DLNA-képes TV** | Ugyanazon a helyi hálózaton, mint a gép (kábel vagy Wi-Fi mindegy). |

A TV-n nem kell semmit telepíteni. LG-n a DLNA-lejátszás alapból be van kapcsolva.

## Telepítés

```powershell
git clone https://github.com/mp3pintyo/acestream.git
cd acestream
```

(vagy töltsd le ZIP-ként, és csomagold ki egy mappába)

**Tűzfal:** az első indításkor a Windows megkérdezheti, hogy a Python fogadhat-e kapcsolatokat
a hálózatról. Engedélyezd azon a hálózattípuson, amelyiken a géped van. Ha a hálózatod
*Nyilvános* (Public), akkor azt is pipáld be, különben a TV nem éri el a proxyt.
Az Ace Stream motornak a telepítője már létrehozza a saját tűzfalszabályát.

## Használat

### A legegyszerűbb: dupla kattintás

1. Indítsd el az Ace Streamet (vagy az Ace Playert) a gépen, és kapcsold be a TV-t.
2. Kattints duplán az **`Ace a TV-re.cmd`** fájlra.
3. Másold be az `acestream://...` linket (vagy csak a 40 karakteres ID-t), és nyomj Entert.
4. Pár másodperc pufferelés után a TV-n elindul az adás.

Paraméterrel is indítható:

```bat
"Ace a TV-re.cmd" acestream://0123456789abcdef0123456789abcdef01234567
"Ace a TV-re.cmd" stop
```

### PowerShellből

```powershell
# Adás küldése a TV-re
.\cast-to-lgtv.ps1 acestream://0123456789abcdef0123456789abcdef01234567

# A hálózaton talált DLNA-lejátszók listája
.\cast-to-lgtv.ps1 -List

# Ha több TV / lejátszó van, név alapján választhatsz
.\cast-to-lgtv.ps1 <ID> -TvName "OLED"

# Lejátszás leállítása a TV-n
.\cast-to-lgtv.ps1 -Stop
```

Ha a PowerShell nem engedi futtatni a szkriptet:
`powershell -ExecutionPolicy Bypass -File .\cast-to-lgtv.ps1 <ID>`

Csatornát váltani úgy tudsz, hogy egyszerűen elküldöd az új linket. A TV leállítja az előzőt,
és az újat kezdi játszani.

## Fájlok

| Fájl | Mit csinál |
|---|---|
| `Ace a TV-re.cmd` | Dupla kattintással indítható. Bekéri a linket, és meghívja a PowerShell-szkriptet. |
| `cast-to-lgtv.ps1` | Megkeresi a TV-t, ellenőrzi, hogy fut-e az Ace motor, ha kell, elindítja a proxyt (rejtett ablakban), majd DLNA-n ráküldi a streamet a TV-re. |
| `ace_tv_proxy.py` | HTTP proxy a 6879-es porton. A `http://<PC-IP>:6879/ace/<ID>.ts` címre érkező kéréseket továbbítja az Ace motornak. Csak a Python standard könyvtárát használja. |

## Hogyan működik részletesen?

1. A `cast-to-lgtv.ps1` a Windows `UPnP.UPnPDeviceFinder` COM-objektumával megkeresi a hálózaton
   a `MediaRenderer` típusú eszközöket. Ha van LG, azt választja.
2. Ellenőrzi, hogy fut-e az Ace Stream motor (`http://127.0.0.1:6878`).
3. Ha a 6879-es porton még nem fut, elindítja a proxyt.
4. A TV-nek a `SetAVTransportURI` paranccsal átadja a `http://<PC-IP>:6879/ace/<ID>.ts`
   címet (DIDL-Lite metaadattal, `video/mp2t` típussal), majd kiadja a `Play` parancsot.
5. A TV meghívja a proxyt. A proxy az Ace motortól a
   `/ace/getstream?id=<ID>&pid=<véletlen>` címen kéri le az adást. A véletlen `pid` miatt
   a TV külön lejátszási munkamenetet kap, így a PC-n futó Ace Player mellett is működik.
6. A motor MPEG-TS-ben adja a streamet (pl. H.264 videó + AC3 hang), és a proxy ezt
   változtatás nélkül továbbítja. Átkódolás nincs, ezért a gépet sem terheli.

## Hibaelhárítás

**„Nem találok TV-t a hálózaton”**
Kapcsold be a TV-t (nem elég készenlétben), és ellenőrizd, hogy ugyanazon a hálózaton van-e.
A `.\cast-to-lgtv.ps1 -List` megmutatja, mit lát a gép.

**„Az Ace Stream motor nem fut”**
Indítsd el az Ace Streamet. Elég, ha a tálcán ott van az ikonja.

**A TV-n nem történik semmi, vagy csak tölt**
- Valószínűleg a tűzfal blokkolja a Pythont. Nézd meg a *Windows Defender tűzfal → Alkalmazás
  engedélyezése* menüben, hogy a `python.exe` engedélyezve van-e a te hálózattípusodon
  (Nyilvános / Magán).
- Próbáld ki, hogy maga az adás él-e: nyisd meg a linket az Ace Playerben a gépen.
- Küldd el még egyszer: néha az első próbálkozásra a TV még „beragad”.

**Megáll a kép a TV-n**
P2P stream, ezért a minőség a forrástól és a többi nézőtől függ. Ha az Ace Playerben is akad,
akkor a TV-n is fog.

**Hogyan állítom le a háttérben futó proxyt?**
A proxy rejtett ablakban fut tovább, amíg ki nem lépsz a Windowsból, vagy le nem állítod:

```powershell
Get-CimInstance Win32_Process -Filter "Name='python.exe'" |
  Where-Object CommandLine -like '*ace_tv_proxy.py*' |
  ForEach-Object { Stop-Process -Id $_.ProcessId }
```

## Korlátok

- Csak Windowson működik (a TV-keresés Windows COM-objektumot használ, a proxy viszont bárhol futna).
- Csak LG webOS TV-n teszteltem.
- A gépnek és az Ace Stream motornak végig futnia kell, mert a TV a gépről kapja a streamet.

## Jogi megjegyzés

Ez a projekt csak egy hálózati segédeszköz, amivel a saját gépeden futó Ace Stream motor
adását a saját TV-den nézheted. Nem tartalmaz és nem ajánl semmilyen adást vagy linket.
Hogy mit nézel, és hogy ahhoz jogod van-e, az a te felelősséged.

Az Ace Stream az Ace Stream fejlesztőinek terméke. Ez a projekt nem kapcsolódik hozzájuk.

## Licenc

MIT – lásd [LICENSE](LICENSE).
