<# =========================================================================
   Universidad: Universidad Nacional de La Matanza (UNLaM)
   Materia: 3641 - Bases de Datos Aplicada
   Fecha: Noviembre 2026
   Integrantes: Matías Ezequiel Chiaravalle, Nahuel Battistelli,
                Agustín Nicolás Mussi Pulcini, Alex Uriel Ruiz
   Objetivo: Script auxiliar para la defensa de la Entrega 6:
             1) Web Scraping real de Wikipedia (List of FIFA World Cup referees)
                -> genera Datos\arbitros_scraping.csv
             2) Consumo en vivo de API 1 (Frankfurter - tipo de cambio)
                -> guarda Datos\api_frankfurter.json (sin API key)
             3) Consumo en vivo de API 2 (Banco Mundial - PBI per cápita)
                -> guarda Datos\api_worldbank_pbi.json (sin API key)
========================================================================= #>

$CarpetaDatos = Split-Path -Parent $MyInvocation.MyCommand.Path

# -------------------------------------------------------------------------
# 1. API 1: Frankfurter (Tipo de cambio base USD)
#    URL: https://api.frankfurter.app/latest?from=USD&to=EUR,BRL,MXN,GBP
#    API Key: NO requiere | Rate limit: uso justo (sin límite estricto)
# -------------------------------------------------------------------------
Write-Host "Descargando API 1 (Frankfurter - Tipo de Cambio)..." -ForegroundColor Cyan
$UrlFrankfurter = "https://api.frankfurter.app/latest?from=USD&to=EUR,BRL,MXN,GBP"
Invoke-WebRequest -Uri $UrlFrankfurter -OutFile (Join-Path $CarpetaDatos "api_frankfurter.json") -UseBasicParsing
Write-Host "  -> Guardado en api_frankfurter.json" -ForegroundColor Green

# -------------------------------------------------------------------------
# 2. API 2: Banco Mundial (Indicador NY.GDP.PCAP.CD - PBI per cápita)
#    URL: https://api.worldbank.org/v2/country/ARG;BRA;USA;ITA;ESP;FRA/indicator/NY.GDP.PCAP.CD?format=json&date=2023
#    API Key: NO requiere | Rate limit: público abierto (<100 req/min recomendado)
# -------------------------------------------------------------------------
Write-Host "Descargando API 2 (Banco Mundial - PBI per cápita)..." -ForegroundColor Cyan
$UrlWorldBank = "https://api.worldbank.org/v2/country/ARG;BRA;USA;ITA;ESP;FRA/indicator/NY.GDP.PCAP.CD?format=json&date=2023"
Invoke-WebRequest -Uri $UrlWorldBank -OutFile (Join-Path $CarpetaDatos "api_worldbank_pbi.json") -UseBasicParsing
Write-Host "  -> Guardado en api_worldbank_pbi.json" -ForegroundColor Green

# -------------------------------------------------------------------------
# 3. WEB SCRAPING: Wikipedia - List of FIFA World Cup referees
#    URL: https://en.wikipedia.org/wiki/List_of_FIFA_World_Cup_referees
#    Técnica: Descarga HTML con Invoke-WebRequest y extracción de filas de
#             tablas wikitable mediante expresiones regulares (regex) en PowerShell.
# -------------------------------------------------------------------------
Write-Host "Haciendo Web Scraping de Wikipedia (Árbitros Mundialistas)..." -ForegroundColor Cyan
$UrlWiki = "https://en.wikipedia.org/wiki/List_of_FIFA_World_Cup_referees"
$Headers = @{ "User-Agent" = "UNLaM-BDA-TP-Mundial2026/1.0" }
$Html = (Invoke-WebRequest -Uri $UrlWiki -Headers $Headers -UseBasicParsing).Content

$FilasCsv = New-Object System.Collections.Generic.List[string]
$FilasCsv.Add("Nombre;Apellido;Nacionalidad;Categoria")

# Extraer filas <tr> de las tablas wikitable (país y nombre del árbitro)
$MatchesTr = [regex]::Matches($Html, '<tr[^>]*>(.*?)</tr>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
$Contador = 0
foreach ($m in $MatchesTr) {
    $Tds = [regex]::Matches($m.Groups[1].Value, '<td[^>]*>(.*?)</td>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($Tds.Count -ge 2) {
        $Col1 = ([regex]::Replace($Tds[0].Groups[1].Value, '<[^>]+>', '') -replace '&nbsp;|\[\d+\]', '').Trim()
        $Col2 = ([regex]::Replace($Tds[1].Groups[1].Value, '<[^>]+>', '') -replace '&nbsp;|\[\d+\]', '').Trim()

        # Tomar filas con nombre y apellido válidos
        if ($Col1 -match '^[A-Za-zÀ-ÿ\s]{3,40}$' -and $Col2 -match '^[A-Za-zÀ-ÿ\-\.]+ [A-Za-zÀ-ÿ\-\.\s]+$') {
            $Partes = $Col2 -split '\s+', 2
            $FilasCsv.Add("$($Partes[0]);$($Partes[1]);$Col1;FIFA")
            $Contador++
            if ($Contador -ge 15) { break }
        }
    }
}

$RutaCsv = Join-Path $CarpetaDatos "arbitros_scraping.csv"
[System.IO.File]::WriteAllLines($RutaCsv, $FilasCsv, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "  -> Scrapeados $Contador árbitros en arbitros_scraping.csv" -ForegroundColor Green
