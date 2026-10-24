param([string]$Device = 'emulator-5554', [string]$ApiBaseUrl)
$ErrorActionPreference = 'Stop'
$toolsRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\.tools'))
$sdkBin = Join-Path $toolsRoot 'flutter-3.47.7\bin'
if (Test-Path -LiteralPath (Join-Path $sdkBin 'flutter.bat')) {
    $env:Path = $sdkBin + ';' + $env:Path
    $env:PUB_CACHE = Join-Path $toolsRoot 'pub-cache'
}
Set-Location -LiteralPath (Join-Path $PSScriptRoot 'HealthBeauty.Mobile')
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed. See the output above.' }
if (-not $ApiBaseUrl) {
    if ($Device -in @('chrome','edge','windows')) { $ApiBaseUrl = 'http://localhost:5230/api/v1' }
    else { $ApiBaseUrl = 'http://10.0.2.2:5230/api/v1' }
}
if ($Device -eq 'chrome') { flutter run -d $Device --web-port=5174 "--dart-define=API_BASE_URL=$ApiBaseUrl" }
else { flutter run -d $Device "--dart-define=API_BASE_URL=$ApiBaseUrl" }
