$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Join-Path $PSScriptRoot 'HealthBeauty.Api')
dotnet run --launch-profile http
