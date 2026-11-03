# Ace Stream -> Smart TV (DLNA / UPnP push), LG webOS TV-n tesztelve
#
# Hasznalat:
#   .\cast-to-lgtv.ps1 acestream://<40 karakteres ID>
#   .\cast-to-lgtv.ps1 <40 karakteres ID>
#   .\cast-to-lgtv.ps1 <ID> -TvName "OLED"     # ha tobb DLNA lejatszo van a halozaton
#   .\cast-to-lgtv.ps1 -List                   # talalt DLNA lejatszok listaja
#   .\cast-to-lgtv.ps1 -Stop                   # lejatszas leallitasa a TV-n
param(
    [Parameter(Position = 0)]
    [string]$Id,
    [string]$TvName,
    [switch]$List,
    [switch]$Stop,
    [int]$ProxyPort = 6879
)

$ErrorActionPreference = 'Stop'

# --- DLNA lejatszok (MediaRenderer) keresese a halozaton ---
Write-Host "DLNA lejatszok keresese..."
$finder = New-Object -ComObject UPnP.UPnPDeviceFinder
$renderers = @($finder.FindByType("urn:schemas-upnp-org:device:MediaRenderer:1", 0))

if ($List) {
    if (-not $renderers) { Write-Host "Nem talaltam DLNA lejatszot."; return }
    $renderers | ForEach-Object { "{0}  |  {1}  |  {2}" -f $_.FriendlyName, $_.ManufacturerName, $_.ModelName }
    return
}

if ($TvName) {
    $tv = $renderers | Where-Object { $_.FriendlyName -like "*$TvName*" } | Select-Object -First 1
} else {
    # LG-t reszesitjuk elonyben, kulonben az elso talalt lejatszo
    $tv = ($renderers | Where-Object { $_.ManufacturerName -like 'LG*' } | Select-Object -First 1)
    if (-not $tv) { $tv = $renderers | Select-Object -First 1 }
}
if (-not $tv) { throw "Nem talalok TV-t a halozaton. Be van kapcsolva, es ugyanazon a halozaton van?" }
Write-Host "TV: $($tv.FriendlyName)"
$avt = $tv.Services.Item("urn:upnp-org:serviceId:AVTransport")

function Invoke-Upnp($svc, $action, [object[]]$inArgs) {
    $out = $null
    $svc.InvokeAction($action, $inArgs, [ref]$out) | Out-Null
    return $out
}

if ($Stop) {
    try { Invoke-Upnp $avt "Stop" @(0) | Out-Null } catch {}
    Write-Host "Leallitva."
    return
}

# --- Ace Stream ID ellenorzese ---
if (-not $Id) { throw "Add meg az Ace Stream linket vagy ID-t (acestream://...)." }
$Id = ($Id.Trim() -replace '^acestream://', '').Trim('/')
if ($Id -notmatch '^[0-9a-fA-F]{40}$') { throw "Ervenytelen Ace Stream ID: '$Id' (40 hexa karakter kell)." }

# --- Ace Stream motor fut? ---
try {
    Invoke-WebRequest -UseBasicParsing "http://127.0.0.1:6878/webui/api/service?method=get_version" -TimeoutSec 5 | Out-Null
} catch {
    throw "Az Ace Stream motor nem fut (127.0.0.1:6878). Inditsd el az Ace Stream-et."
}

# --- A PC LAN IP-je (az a halozati kartya, amin alapertelmezett atjaro van) ---
$pcIp = (Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway } | Select-Object -First 1).IPv4Address.IPAddress
if (-not $pcIp) { throw "Nem talalom a gep helyi IP-cimet." }

# --- Proxy inditasa, ha meg nem fut ---
# Az Ace motor a HEAD keresre 501-et ad, az LG pedig lejatszas elott HEAD-et kuld.
# Az ace_tv_proxy.py ezt kezeli, es tovabbitja a streamet.
if (-not (Get-NetTCPConnection -State Listen -LocalPort $ProxyPort -ErrorAction SilentlyContinue)) {
    $py = (Get-Command python.exe -ErrorAction SilentlyContinue).Source
    if (-not $py) { throw "Nem talalom a Pythont (python.exe a PATH-on). Telepitsd: https://www.python.org/downloads/" }
    Write-Host "Proxy inditasa ($py, port $ProxyPort)..."
    Start-Process -FilePath $py -ArgumentList "-I", "`"$PSScriptRoot\ace_tv_proxy.py`"", $ProxyPort -WindowStyle Hidden
    Start-Sleep -Seconds 2
}

$url = "http://${pcIp}:${ProxyPort}/ace/$Id.ts"
Write-Host "Stream URL: $url"

# --- DLNA: URL atadasa a TV-nek, majd lejatszas ---
$proto = "http-get:*:video/mp2t:DLNA.ORG_OP=00;DLNA.ORG_CI=0;DLNA.ORG_FLAGS=01700000000000000000000000000000"
$didl = '<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">' +
        '<item id="0" parentID="-1" restricted="1"><dc:title>Ace Stream</dc:title><upnp:class>object.item.videoItem</upnp:class>' +
        "<res protocolInfo=`"$proto`">$([System.Security.SecurityElement]::Escape($url))</res></item></DIDL-Lite>"

try { Invoke-Upnp $avt "Stop" @(0) | Out-Null } catch {}
Invoke-Upnp $avt "SetAVTransportURI" @(0, $url, $didl) | Out-Null
# Az LG a Play-re sokszor hibakodot ad, mikozben megis elinditja a lejatszast -> nem kezeljuk hibanak
try { Invoke-Upnp $avt "Play" @(0, "1") | Out-Null } catch {}
Write-Host "Elkuldve a TV-re. Par masodperc puffereles utan indul a kep."
