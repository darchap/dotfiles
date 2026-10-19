# Windows setup. On a new machine:
#   git clone https://github.com/darchap/dotifles.git $HOME\dotfiles
#   powershell -ExecutionPolicy Bypass -File $HOME\dotfiles\windows\install.ps1
# Safe to re-run; re-run after a pull to refresh the copied ruff and Windows Terminal settings.
$DotfilesDir = Split-Path $PSScriptRoot

function Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Set-Prop($obj, $name, $value) { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value -Force }

Step 'Packages'
foreach ($id in 'Microsoft.WindowsTerminal', 'Microsoft.PowerShell', 'Starship.Starship', 'ajeetdsouza.zoxide', 'junegunn.fzf') {
	winget list -e --id $id --accept-source-agreements *> $null
	if ($LASTEXITCODE -eq 0) { Write-Host "  $id already installed"; continue }
	winget install -e --id $id --silent --accept-package-agreements --accept-source-agreements
	if ($LASTEXITCODE -ne 0) { Write-Warning "  winget failed for $id (exit $LASTEXITCODE)" }
}
$env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('PATH', 'User')

Step 'MesloLGM Nerd Font'
Add-Type -AssemblyName System.Drawing
if ((New-Object System.Drawing.Text.InstalledFontCollection).Families.Name -contains 'MesloLGM Nerd Font') {
	Write-Host '  already installed'
} else {
	$tmp = Join-Path $env:TEMP 'meslo-nf'
	New-Item -ItemType Directory -Force $tmp | Out-Null
	$ProgressPreference = 'SilentlyContinue'
	Invoke-WebRequest https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip -OutFile "$tmp\Meslo.zip"
	Expand-Archive "$tmp\Meslo.zip" "$tmp\x" -Force
	$fontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
	New-Item -ItemType Directory -Force $fontDir | Out-Null
	$reg = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
	Get-ChildItem "$tmp\x" -Filter 'MesloLGMNerdFont-*.ttf' | ForEach-Object {
		$dest = Join-Path $fontDir $_.Name
		Copy-Item $_.FullName $dest -Force
		New-ItemProperty -Path $reg -Name "$($_.BaseName) (TrueType)" -Value $dest -PropertyType String -Force | Out-Null
	}
	Remove-Item $tmp -Recurse -Force
	Write-Host '  installed for this user; restart open apps to see it'
}

Step 'Terminal-Icons and PSFzf modules (PowerShell 7)'
# 7.6+ installs as MSIX, so look it up on PATH rather than under Program Files
$pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if ($pwsh) {
	& $pwsh -NoProfile -Command 'foreach ($m in ''Terminal-Icons'', ''PSFzf'') { if (-not (Get-Module -ListAvailable $m)) { Install-Module $m -Scope CurrentUser -Force } }'
} else { Write-Warning '  pwsh not found, skipped' }

Step 'PowerShell profiles'
if ((Get-ExecutionPolicy) -in 'Restricted', 'AllSigned', 'Undefined') {
	Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
}
$stub = ". `"$DotfilesDir\windows\profile.ps1`""
$docs = [Environment]::GetFolderPath('MyDocuments')
foreach ($p in "$docs\PowerShell\Microsoft.PowerShell_profile.ps1", "$docs\WindowsPowerShell\Microsoft.PowerShell_profile.ps1") {
	if ((Test-Path $p) -and (Select-String -SimpleMatch $stub $p -Quiet)) { Write-Host "  $p already set"; continue }
	New-Item -ItemType Directory -Force (Split-Path $p) | Out-Null
	Add-Content $p $stub
	Write-Host "  $p"
}

Step 'Git'
$inc = "$DotfilesDir\.gitconfig" -replace '\\', '/'
if ((git config --global --get-all include.path) -notcontains $inc) { git config --global --add include.path $inc }
Write-Host "  ~/.gitconfig includes $inc"
if (-not (Test-Path "$HOME\.ssh\signing")) {
	New-Item -ItemType Directory -Force "$HOME\.ssh" | Out-Null
	# Via cmd: Windows PowerShell drops an empty "" argument, so ssh-keygen would prompt for a passphrase
	cmd /c "ssh-keygen -q -t ed25519 -N `"`" -C `"$env:USERNAME@$env:COMPUTERNAME signing`" -f `"$HOME\.ssh\signing`""
	Write-Host '  created ~/.ssh/signing; add ~/.ssh/signing.pub at https://github.com/settings/ssh/new as a Signing Key'
}

Step 'Ruff'
New-Item -ItemType Directory -Force "$env:APPDATA\ruff" | Out-Null
Copy-Item "$DotfilesDir\.config\ruff\ruff.toml" "$env:APPDATA\ruff\ruff.toml" -Force
Write-Host "  $env:APPDATA\ruff\ruff.toml"

Step 'Windows Terminal'
$wtDir = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
$wtFile = "$wtDir\settings.json"
$breeze = Get-Content -Raw "$PSScriptRoot\terminal\breeze.json" | ConvertFrom-Json
if (Test-Path $wtFile) {
	Copy-Item $wtFile "$wtFile.bak" -Force
	# Windows PowerShell's JSON parser rejects the // comments Windows Terminal writes
	$s = ((Get-Content $wtFile) | Where-Object { $_ -notmatch '^\s*//' }) -join "`n" | ConvertFrom-Json
} else {
	New-Item -ItemType Directory -Force $wtDir | Out-Null
	$s = [pscustomobject]@{}
}
Set-Prop $s schemes (@($s.schemes | Where-Object { $_ -and $_.name -ne 'Breeze' }) + $breeze.schemes)
if ($s.profiles -is [array]) { Set-Prop $s profiles ([pscustomobject]@{ list = $s.profiles }) }
if (-not $s.profiles) { Set-Prop $s profiles ([pscustomobject]@{}) }
if (-not $s.profiles.defaults) { Set-Prop $s.profiles defaults ([pscustomobject]@{}) }
foreach ($kv in $breeze.defaults.PSObject.Properties) { Set-Prop $s.profiles.defaults $kv.Name $kv.Value }
if ($pwsh) { Set-Prop $s defaultProfile '{574e775e-4f2a-5b96-ac1e-a2962a402336}' }  # PowerShell 7's fixed profile id
[IO.File]::WriteAllText($wtFile, ($s | ConvertTo-Json -Depth 32))
Write-Host "  $wtFile"

Step 'Done. Open Windows Terminal to see it.'
