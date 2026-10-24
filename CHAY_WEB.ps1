$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Join-Path $PSScriptRoot 'HealthBeauty.Web')
if (-not (Test-Path -LiteralPath 'node_modules')) { throw 'Run npm ci in HealthBeauty.Web first.' }
npm run dev -- --configLoader native --port 5173
