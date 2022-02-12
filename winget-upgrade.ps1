#requires -Version 5.1
#requires -RunAsAdministrator

<#
winget-upgrade.ps1

Author: https://github.com/mineugene
DateCreated: 2022-02-12
Description: verifies and installs/upgrades programs listed in
  'winget-upgrade.json' and installs them one at a time.
#>

#region SCRIPTBLOCKS - atomic jobs to run asynchronously
$resolve_names = {
  param($prog)

  winget show --exact --id="$prog" >$null
  if ($lastexitcode -ne 0) { "$prog" }
}
$find_installed = {
  param($prog)

  winget list --exact --id="$prog" >$null
  if ($lastexitcode -eq 0) { "$prog" }
}
#endregion SCRIPTBLOCKS

#region HELPERS - cleans up MAIN region
function Iterate-Async {
  param($Cmd, $ArgsList)

  $tasks = @()
  foreach ($a in $ArgsList) {
    $tasks += start-job -argumentlist $a -scriptblock $Cmd
  }
  return $tasks
}

function Resolve-All {
  param($tasks)

  wait-job -job $tasks | Out-Null
  return ($tasks | % {receive-job $_.Id;remove-job $_.Id}) -split ' '
}

function WinGet-Install {
  param($programs)

  write-header "Retrieving packages"
  foreach ($p in $programs) {
    write-host -nonewline "$p downloading..."
    winget install --silent --exact --id $p >$null
    if ($lastexitcode -ne 0) {
      write-host "FAILED" -foregroundcolor red
    } else {
      write-host "DONE"
    }
  }
}

function WinGet-Upgrade {
  param($programs)

  write-header "Upgrading packages"
  foreach ($p in $programs) {
    write-host -nonewline "upgrading $p..."
    winget upgrade --silent --exact --id $p >$null
    if ($lastexitcode -ne 0) {
      write-host "SKIPPED" -foregroundcolor yellow
    } else {
      write-host "DONE"
    }
  }
}

function Write-Header {
  param($text, [switch]$nonewline)

  write-host -nonewline ":: " -foregroundcolor blue
  write-host -nonewline "$text" -foregroundcolor white
  if (!$nonewline) { write-host "..." }
}

function WordWrap-List {
  param($words)

  $max_width = $host.ui.rawui.windowsize.width
  $line_length = 0
  $result = [System.Text.StringBuilder]::new()

  if ($max_width -eq $null) {
    $max_width = 0
  }
  foreach ($word in $words) {
    if ($line_length -gt ($max_width - $word.Length - 5)) {
      $result.append("`n") >$null
      $line_length = 0
    }
    $result.append("$word ") >$null
    $line_length += $word.Length
  }
  return $result.tostring()
}
#endregion HELPERS

#region MAIN
$programs = get-content "winget-upgrade.json" | convertfrom-json
if (
  !$? -or
  !(get-command winget)
) {
  exit 0xffffffff
}

write-header "Starting full upgrade"

write-host -nonewline "resolving packages..."
$tasks_resolve = iterate-async -cmd $resolve_names -argslist $programs.programs
$unresolved = resolve-all -tasks $tasks_resolve
write-host "DONE"
if ($unresolved.Length -gt 0) { 
  write-error -category NotInstalled `
    -message "$($unresolved.Item(0)) : target not found."
  exit 0xffffffff
}

write-host -nonewline "looking for conflicting packages..."
$tasks_exists = iterate-async -cmd $find_installed -argslist $programs.programs
$installed = resolve-all -tasks $tasks_exists
write-host "DONE"
$new_programs = $programs.programs
foreach ($prog_name in $installed) {
  # filter out programs already installed on system
  $new_programs = $new_programs -ne $prog_name
}

write-host ""
# stats: programs to be installed/upgraded, print to stdout
if ($new_programs.Length -gt 0) {
  write-host "Installing ($($new_programs.Length))"
  write-host "$(wordwrap-list $new_programs)`n" -foregroundcolor blue
}
if ($installed.Length -gt 0) {
  write-host "Upgrading ($($installed.Length))"
  write-host "$(wordwrap-list $installed)`n" -foregroundcolor blue
}

write-header -nonewline "Proceed with installation? [Y/n] "
$response = (read-host).trim().tolower()
switch ($response) {
  "n" { exit }
  {$_ -in "y", ""} {
    winget-install -programs $new_programs
    winget-upgrade -programs $installed
    break
  }
  default {
    write-error -category InvalidOperation `
      -message "$response : unrecognized response." `
      -recommendedaction "the expected response is [Y]es (proceed with upgrade) or [N]o (cancel all)."
    exit 0xffffffff
  }
}
#endregion MAIN
