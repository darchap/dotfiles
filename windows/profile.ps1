# Loaded from $PROFILE by a one-line stub that install.ps1 writes. Works in PowerShell 7 and 5.1.
$DotfilesDir = Split-Path $PSScriptRoot

# --- Path
if (Test-Path "$HOME\bin") { $env:PATH = "$HOME\bin;$env:PATH" }

# --- Line editing (zsh bindings, autosuggestions, history)
if (Get-Module -ListAvailable PSReadLine) {
	Set-PSReadLineOption -MaximumHistoryCount 32767 -HistoryNoDuplicates -BellStyle None
	# Commands starting with a space stay out of history, like zsh hist_ignore_space
	Set-PSReadLineOption -AddToHistoryHandler { param($line) -not $line.StartsWith(' ') }
	Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
	Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
	Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
	Set-PSReadLineKeyHandler -Chord 'Alt+l' -ScriptBlock {
		[Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
		[Microsoft.PowerShell.PSConsoleReadLine]::Insert('ls')
		[Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
	}
	# Inline suggestions need PSReadLine 2.1+; Windows PowerShell 5.1 ships 2.0
	try { Set-PSReadLineOption -PredictionSource History -ErrorAction Stop } catch {}
}

# --- Shortcuts
function reloadshell { . $PROFILE }
function aliases { Select-String '^function ' $PSCommandPath | ForEach-Object { $_.Line } }
Set-Alias c Clear-Host
function ll { Get-ChildItem -Force @args }
function findsymlinks { Get-ChildItem -Recurse -Force -ErrorAction SilentlyContinue | Where-Object LinkType }
function findhere($pattern) { Get-ChildItem -Recurse -Name -ErrorAction SilentlyContinue | Select-String $pattern }
function tarnow { tar.exe -acf @args }
function untar { tar.exe -xvf @args }

# --- Memory
function psmem($n = 0) {
	$p = Get-Process | Sort-Object WorkingSet64 -Descending
	if ($n) { $p = $p | Select-Object -First $n }
	$p | Format-Table Id, ProcessName, @{ n = 'MB'; e = { [math]::Round($_.WorkingSet64 / 1MB) } } -AutoSize
}
function psmem10 { psmem 10 }

# --- Navigation
function .. { Set-Location .. }
function ... { Set-Location ..\.. }
function .... { Set-Location ..\..\.. }
function ..... { Set-Location ..\..\..\.. }
function ...... { Set-Location ..\..\..\..\.. }

function week { Get-Date -UFormat %V }
function ip { (Invoke-RestMethod ifconfig.me/ip).Trim() }

# --- Git
function undolastcommit { git reset --hard HEAD~1; if ($?) { git push origin -f } }
function filesbeforecommit { git diff --name-only --staged }
function glog { git log --graph --pretty=format:'%Cred%h%Creset %an: %s - %Creset %C(yellow)%d%Creset %Cgreen(%cr)%Creset' --abbrev-commit --date=relative @args }
# Drop the leading +/-/space from diff lines; colour alone shows the change
function gdiff { git diff --color @args | ForEach-Object { $_ -replace '^((?:\e\[[0-9;]*m)*)[-+ ]', '$1' } }
function gstatus { git status -sb }

# --- Functions
function backupfile($path) { Copy-Item $path "$path.bak" }
function upgrade { winget upgrade --all --accept-package-agreements --accept-source-agreements }
function venvhere($name) {
	if (-not $name) { Write-Host 'Usage: venvhere <env_name>'; return }
	python -m venv $name
	if ($LASTEXITCODE) { Write-Host "Error: virtual environment $name could not be created."; return }
	& "$name\Scripts\Activate.ps1"
	Write-Host "Virtual environment $name created and activated."
}
function colormap {
	$e = [char]27
	foreach ($i in 0..255) {
		Write-Host -NoNewline ("$e[48;5;${i}m  $e[0m$e[38;5;${i}m{0:D3}$e[0m " -f $i)
		if ($i % 6 -eq 3) { Write-Host }
	}
	Write-Host
}

# --- Prompt
if (Get-Module -ListAvailable Terminal-Icons) { Import-Module Terminal-Icons }
if (Get-Command starship -ErrorAction SilentlyContinue) {
	$env:STARSHIP_CONFIG = "$DotfilesDir\.config\starship.toml"
	$env:STARSHIP_DISTRO = "$([char]0xF17A) "  # nf-fa-windows; char code because 5.1 reads BOM-less files as ANSI
	Invoke-Expression (& starship init powershell)
}
