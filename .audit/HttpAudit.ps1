$ErrorActionPreference='Stop'
$env:ASPNETCORE_ENVIRONMENT='Development'
$env:Jwt__Key=([Guid]::NewGuid().ToString('N')+[Guid]::NewGuid().ToString('N'))
$env:Jwt__Issuer='AuditCheck'
$env:Jwt__Audience='AuditClient'
$env:ConnectionStrings__DefaultConnection='Server=localhost\SQLEXPRESS;Database=KLCN021_HealthBeauty;Trusted_Connection=True;TrustServerCertificate=True;Connect Timeout=3;'
function B64([byte[]]$Bytes) { [Convert]::ToBase64String($Bytes).TrimEnd('=').Replace('+','-').Replace('/','_') }
function Token([string]$Role,[int]$AccountId) {
 $header=B64 ([Text.Encoding]::UTF8.GetBytes('{"alg":"HS256","typ":"JWT"}'))
 $payload=B64 ([Text.Encoding]::UTF8.GetBytes((@{sub="$AccountId";role=$Role;iss='AuditCheck';aud='AuditClient';exp=[DateTimeOffset]::UtcNow.AddMinutes(10).ToUnixTimeSeconds()} | ConvertTo-Json -Compress)))
 $hmac=New-Object Security.Cryptography.HMACSHA256
 $hmac.Key=[Text.Encoding]::UTF8.GetBytes($env:Jwt__Key)
 $signature=B64 ($hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes("$header.$payload")))
 "$header.$payload.$signature"
}
# Resolve actual database account roles; token validation now rejects fabricated role/account pairs.
$sqlConnection=New-Object System.Data.SqlClient.SqlConnection($env:ConnectionStrings__DefaultConnection)
$sqlConnection.Open()
try {
 $accountCommand=$sqlConnection.CreateCommand()
 $accountCommand.CommandText="SELECT a.TaiKhoanID,r.TenVaiTro FROM dbo.TAIKHOAN a JOIN dbo.VAITRO r ON r.VaiTroID=a.VaiTroID WHERE a.TrangThai=1 AND (a.KhoaDen IS NULL OR a.KhoaDen<=SYSUTCDATETIME()) ORDER BY a.TaiKhoanID"
 $reader=$accountCommand.ExecuteReader()
 $testAccounts=@()
 while($reader.Read()) {$testAccounts+=[pscustomobject]@{Id=$reader.GetInt32(0);Role=$reader.GetString(1)}}
 $reader.Close()
} finally {$sqlConnection.Dispose()}
$adminId=($testAccounts | Where-Object Role -eq 'Admin' | Select-Object -First 1).Id
if(-not $adminId) {throw 'No active Admin fixture for read-only HTTP audit'}
$staffAccountId=($testAccounts | Where-Object Role -eq 'Staff' | Select-Object -First 1).Id
$base='http://127.0.0.1:15231'
$repo=(Get-Location).Path
$outLog=Join-Path $repo '.audit\http-out.log';$errLog=Join-Path $repo '.audit\http-err.log'
$process=Start-Process dotnet -ArgumentList @('bin\Debug\net8.0\HealthBeauty.Api.dll','--urls',$base) -WorkingDirectory (Join-Path $repo 'HealthBeauty.Api') -WindowStyle Hidden -PassThru -RedirectStandardOutput $outLog -RedirectStandardError $errLog
try {
 Start-Sleep -Seconds 2
 $swagger=Invoke-RestMethod "$base/swagger/v1/swagger.json" -TimeoutSec 4
 $swagger | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath '.audit\swagger.json' -Encoding UTF8
 $routes=@()
 foreach($entry in $swagger.paths.PSObject.Properties) {
  foreach($operation in $entry.Value.PSObject.Properties) {
   if($operation.Name -in @('get','post','put','patch','delete','head','options')) {$routes+=[pscustomobject]@{method=$operation.Name.ToUpperInvariant();path=$entry.Name}}
  }
 }
 $routes | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath 'API_AUDIT_ROUTES.json' -Encoding UTF8

 $adminHeaders=@{Authorization=('Bearer '+(Token 'Admin' $adminId))}
 $accounts=Invoke-RestMethod "$base/api/v1/admin/accounts" -Headers $adminHeaders -TimeoutSec 6
 $customer=($accounts | Where-Object {$_.role -eq 'Customer'} | Select-Object -First 1).taiKhoanId
 if(-not $customer) {$customer=3}
 $staff=Invoke-RestMethod "$base/api/v1/staff" -Headers $adminHeaders -TimeoutSec 6
 $staffId=($staff | Select-Object -First 1).nhanVienId
 if(-not $staffId) {$staffId=1}
 $appointments=Invoke-RestMethod "$base/api/v1/appointments" -Headers $adminHeaders -TimeoutSec 6
 $appointmentId=($appointments.items | Select-Object -First 1).id
 if(-not $appointmentId) {$appointmentId=1}
 $results=@()
 foreach($entry in $swagger.paths.PSObject.Properties) {
  if(-not $entry.Value.get) {continue}
  $path=$entry.Name
  $role='Admin';$accountId=$adminId
  if($path -match '/staff/me/' -and $staffAccountId) {$role='Staff';$accountId=$staffAccountId}
  if($path -match '/customers/me') {$role='Customer';$accountId=$customer}
  $urlPath=$path -replace '\{roleId\}','1' -replace '\{id\}',$(if($path -match '/appointments/') {"$appointmentId"} elseif($path -match '/staff/') {"$staffId"} else {'1'})
  if($path -match 'availability|available-slots') {$urlPath+='?date='+(Get-Date -Format 'yyyy-MM-dd')}
  $headers=@{Authorization=('Bearer '+(Token $role $accountId))}
  $status=0;$errorKind='';$shape=''
  try {
   $response=Invoke-WebRequest ($base+$urlPath) -Headers $headers -UseBasicParsing -TimeoutSec 8
   $status=[int]$response.StatusCode
   if($response.Content.TrimStart().StartsWith('[')) {$shape='array'} else {$shape='object'}
  } catch {
   if($_.Exception.Response) {$status=[int]$_.Exception.Response.StatusCode}
   $detail=$_.ErrorDetails.Message
   if($detail -match 'cycle|depth') {$errorKind='JSON reference cycle'}
   elseif($detail -match 'could not be translated|InvalidOperationException') {$errorKind='EF query/runtime exception'}
   elseif($detail -match 'SqlException') {$errorKind='SQL exception'}
   elseif($status -eq 0) {$errorKind='timeout/connection'}
  }
  $result=[pscustomobject]@{Method='GET';Path=$path;Status=$status;Role=$role;Shape=$shape;Error=$errorKind}
  $results+=$result
  "$status GET $path [$role] $errorKind"
 }
 $results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath 'API_AUDIT_HTTP.json' -Encoding UTF8
 $unknownHeaders=@{Authorization=('Bearer '+(Token 'Admin' 2147483647))}
 $unknownStatus=0
 try {$response=Invoke-WebRequest "$base/api/v1/admin/roles" -Headers $unknownHeaders -UseBasicParsing -TimeoutSec 6;$unknownStatus=[int]$response.StatusCode}
 catch {if($_.Exception.Response) {$unknownStatus=[int]$_.Exception.Response.StatusCode}}
 "Missing-account signed JWT HTTP: $unknownStatus (expected401)"
 if($unknownStatus -ne 401) {throw 'Account token validation regression'}
 $customerHeaders=@{Authorization=('Bearer '+(Token 'Customer' $customer))}
 $paymentStatus=0
 try {
  $response=Invoke-WebRequest "$base/api/v1/invoices/1/payments" -Method Post -Headers $customerHeaders -ContentType 'application/json' -Body '{"method":"TienMat","status":"ThanhCong"}' -UseBasicParsing -TimeoutSec 6
  $paymentStatus=[int]$response.StatusCode
 } catch {if($_.Exception.Response) {$paymentStatus=[int]$_.Exception.Response.StatusCode}}
 "Customer payment confirmation HTTP: $paymentStatus (expected403)"
 if($paymentStatus -ne 403) {throw 'Customer payment authorization regression'}
 'GET count: '+$results.Count
 'Server errors: '+@($results | Where-Object {$_.Status -ge 500 -or $_.Status -eq 0}).Count
} finally {
 if(-not $process.HasExited) {Stop-Process -Id $process.Id -Force}
 Remove-Item -LiteralPath $outLog,$errLog -Force -ErrorAction SilentlyContinue
 Remove-Item -LiteralPath (Join-Path $repo '.audit\swagger.json') -Force -ErrorAction SilentlyContinue
}
