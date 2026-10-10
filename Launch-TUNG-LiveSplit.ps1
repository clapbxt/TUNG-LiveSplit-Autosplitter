param([string]$LiveSplit = '')
$ErrorActionPreference = 'Stop'
if (-not $LiveSplit) {
    Add-Type -AssemblyName System.Windows.Forms
    $picker = New-Object System.Windows.Forms.OpenFileDialog
    $picker.Title = 'Select your LiveSplit.exe'
    $picker.Filter = 'LiveSplit executable (LiveSplit.exe)|LiveSplit.exe'
    if ($picker.ShowDialog() -ne 'OK') { return }
    $LiveSplit = Split-Path -Parent $picker.FileName
    $picker.Dispose()
}
$exe = Join-Path $LiveSplit 'LiveSplit.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw "LiveSplit.exe not found in $LiveSplit" }
$layoutPath = Join-Path $PSScriptRoot 'TUNG.lsl'
$runPath = Join-Path $PSScriptRoot 'TUNG-AnyPercent.lss'
[xml]$layout = Get-Content -LiteralPath $layoutPath
$layout.SelectSingleNode("//Component[Path='LiveSplit.ScriptableAutoSplit.dll']/Settings/ScriptPath").InnerText = Join-Path $PSScriptRoot 'TUNG.asl'
$layout.Save($layoutPath)
[xml]$run = Get-Content -LiteralPath $runPath
$run.SelectSingleNode("//LayoutPath").InnerText = $layoutPath
$run.Save($runPath)
if (Get-Process LiveSplit -ErrorAction SilentlyContinue) {
    Write-Host "LiveSplit is already running. Open Splits > From File: $runPath"
    Write-Host "Then Open Layout > From File: $layoutPath"
    return
}
Start-Process -FilePath $exe -WorkingDirectory $LiveSplit -ArgumentList '-s',('"'+$runPath+'"'),'-l',('"'+$layoutPath+'"')
