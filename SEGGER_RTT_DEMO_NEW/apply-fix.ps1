<#
.SYNOPSIS
    Adds SEGGER RTT logging (printf + LOG_xxx over RTT) to an STM32CubeIDE
    project for STM32H723 and prepares OpenOCD/ST-LINK viewing on
    localhost:19021 (PuTTY / Tera Term / CubeIDE Terminal).

.DESCRIPTION
    1. Backs up .cproject, *.ld and Core/Src/main.c
    2. Copies the RTT sources into <project>\SeggerRTT\Inc and \Src
    3. Adds a NOLOAD ".rtt_dtcm" section (DTCM, 0x20000000) to every linker script
    4. Registers SeggerRTT as a source folder and SeggerRTT/Inc as include path
       (all build configurations) in .cproject
    5. Adds the RTT demo code to main.c (inside USER CODE sections only)
    6. Copies the OpenOCD / PuTTY / Tera Term helpers to <project>\RTT_Tools

    Safe to run more than once. CLOSE STM32CubeIDE BEFORE RUNNING.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\apply-fix.ps1
    powershell -ExecutionPolicy Bypass -File .\apply-fix.ps1 -ProjectDir "D:\ws\MyProj"
#>
[CmdletBinding()]
param(
    [string]$ProjectDir = "C:\STM32_NEW_WORKSPACE\SEGGER_RTT_DEMO_NEW",
    [switch]$NoMainPatch
)

$ErrorActionPreference = 'Stop'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$PkgDir    = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Step([string]$msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok([string]$msg)   { Write-Host "    [OK]   $msg" -ForegroundColor Green }
function Write-Skip([string]$msg) { Write-Host "    [SKIP] $msg" -ForegroundColor DarkGray }
function Write-Warn2([string]$msg){ Write-Host "    [WARN] $msg" -ForegroundColor Yellow }

function Read-Text([string]$path)  { return [System.IO.File]::ReadAllText($path) }
function Save-Text([string]$path, [string]$text) { [System.IO.File]::WriteAllText($path, $text, $Utf8NoBom) }

# ---------------------------------------------------------------------------
Write-Step "Checking project: $ProjectDir"
# ---------------------------------------------------------------------------
if (-not (Test-Path (Join-Path $ProjectDir '.cproject'))) {
    throw "No .cproject found in '$ProjectDir'. Pass -ProjectDir <your CubeIDE project folder>."
}
$ProjectDir = (Resolve-Path $ProjectDir).Path
$MainC      = Join-Path $ProjectDir 'Core\Src\main.c'
if (-not (Test-Path $MainC)) { throw "Core\Src\main.c not found - generate code with CubeMX first." }

$ide = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^stm32cubeide' }
if ($ide) {
    Write-Warn2 "STM32CubeIDE is running. Close it now (it rewrites .cproject on exit)."
    Read-Host "    Press ENTER after closing STM32CubeIDE" | Out-Null
}
Write-Ok "Project found"

# ---------------------------------------------------------------------------
Write-Step "Backup"
# ---------------------------------------------------------------------------
$stamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
$Backup = Join-Path $ProjectDir "_rtt_backup_$stamp"
New-Item -ItemType Directory -Path $Backup | Out-Null
Copy-Item (Join-Path $ProjectDir '.cproject') $Backup
Copy-Item $MainC $Backup
Get-ChildItem -Path $ProjectDir -Filter '*.ld' -File | Copy-Item -Destination $Backup
Write-Ok "Saved to $Backup"

# ---------------------------------------------------------------------------
Write-Step "Copying RTT sources"
# ---------------------------------------------------------------------------
$DstRoot = Join-Path $ProjectDir 'SeggerRTT'
$DstInc  = Join-Path $DstRoot 'Inc'
$DstSrc  = Join-Path $DstRoot 'Src'
New-Item -ItemType Directory -Force -Path $DstInc, $DstSrc | Out-Null

# Files that must NOT be compiled together with this package
$conflicts = @('SEGGER_RTT_Syscalls_GCC.c', 'SEGGER_RTT_Syscalls_IAR.c', 'SEGGER_RTT_Syscalls_KEIL.c',
               'SEGGER_RTT_Syscalls_SES.c', 'SEGGER_RTT_ASM_ARMv7M.S', 'SEGGER_RTT_ASM_ARMv7M.s')
$ours = @(Get-ChildItem (Join-Path $PkgDir 'SeggerRTT\Inc'), (Join-Path $PkgDir 'SeggerRTT\Src') -File |
          ForEach-Object { $_.Name })

if (Test-Path $DstRoot) {
    Get-ChildItem -Path $DstRoot -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($DstRoot.Length).TrimStart('\')
        $isConflict  = $conflicts -contains $_.Name
        # Same file name in another sub-folder (e.g. SeggerRTT\Config\SEGGER_RTT_Conf.h) -> duplicate
        $isDuplicate = ($ours -contains $_.Name) -and ($_.DirectoryName -ne $DstInc) -and ($_.DirectoryName -ne $DstSrc)
        if ($isConflict -or $isDuplicate) {
            $target = Join-Path $Backup ("SeggerRTT_removed\" + $rel)
            New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
            Move-Item $_.FullName $target -Force
            Write-Warn2 "Moved conflicting file to backup: SeggerRTT\$rel"
        }
    }
}

Copy-Item (Join-Path $PkgDir 'SeggerRTT\Inc\*') $DstInc -Force
Copy-Item (Join-Path $PkgDir 'SeggerRTT\Src\*') $DstSrc -Force
if (Test-Path (Join-Path $PkgDir 'SeggerRTT\LICENSE_SEGGER_RTT.md')) {
    Copy-Item (Join-Path $PkgDir 'SeggerRTT\LICENSE_SEGGER_RTT.md') $DstRoot -Force
}
Write-Ok "SeggerRTT\Inc : $((Get-ChildItem $DstInc -File).Name -join ', ')"
Write-Ok "SeggerRTT\Src : $((Get-ChildItem $DstSrc -File).Name -join ', ')"

# ---------------------------------------------------------------------------
Write-Step "Patching linker scripts (.rtt_dtcm -> DTCM)"
# ---------------------------------------------------------------------------
$ldFiles = Get-ChildItem -Path $ProjectDir -Filter '*.ld' -File
if (-not $ldFiles) { Write-Warn2 "No *.ld file in project root - add the section manually (see README)." }

foreach ($ld in $ldFiles) {
    $text = Read-Text $ld.FullName
    if ($text -match '\.rtt_dtcm') { Write-Skip "$($ld.Name): already patched"; continue }

    # Region whose ORIGIN is 0x20000000 (DTCMRAM in new CubeMX, RAM in older ones)
    $m = [regex]::Match($text, '(?im)^\s*([A-Za-z_][A-Za-z0-9_]*)\s*\([^)]*\)\s*:\s*ORIGIN\s*=\s*0x0*20000000\b')
    if (-not $m.Success) { Write-Warn2 "$($ld.Name): no memory region at 0x20000000 - skipped"; continue }
    $region = $m.Groups[1].Value

    $nl = "`n"; if ($text -match "`r`n") { $nl = "`r`n" }
    $section = @(
        "  /* SEGGER RTT control block + buffers: DTCM is not cached, so the debug",
        "     probe always sees the current data (D-Cache is ON). Added by apply-fix.ps1 */",
        "  .rtt_dtcm (NOLOAD) :",
        "  {",
        "    . = ALIGN(8);",
        "    KEEP(*(.rtt_dtcm))",
        "    KEEP(*(.rtt_dtcm.*))",
        "    . = ALIGN(8);",
        "  } >$region",
        "",
        ""
    ) -join $nl

    # Insert just before the ".data" output section
    $d = [regex]::Match($text, '(?m)^[ \t]*\.data[ \t]*:')
    if (-not $d.Success) { Write-Warn2 "$($ld.Name): '.data :' section not found - skipped"; continue }

    $text = $text.Insert($d.Index, $section)
    Save-Text $ld.FullName $text
    Write-Ok "$($ld.Name): .rtt_dtcm added in region '$region'"
}

# ---------------------------------------------------------------------------
Write-Step "Patching .cproject (source folder + include path, all configurations)"
# ---------------------------------------------------------------------------
$cprojPath = Join-Path $ProjectDir '.cproject'
$xml = New-Object System.Xml.XmlDocument
$xml.PreserveWhitespace = $true
$xml.Load($cprojPath)
$changed = $false

# a) include path ../SeggerRTT/Inc for the C compiler
$incOpts = $xml.SelectNodes("//option[contains(@superClass,'c.compiler.option.includepaths')]")
foreach ($opt in $incOpts) {
    $has = $opt.SelectSingleNode("listOptionValue[@value='../SeggerRTT/Inc']")
    if (-not $has) {
        $lv = $xml.CreateElement('listOptionValue')
        $lv.SetAttribute('builtIn', 'false')
        $lv.SetAttribute('value', '../SeggerRTT/Inc')
        [void]$opt.AppendChild($lv)
        $changed = $true
    }
}
if ($incOpts.Count -eq 0) { Write-Warn2 "No C include-path option found - add ../SeggerRTT/Inc manually." }
else { Write-Ok "Include path ../SeggerRTT/Inc ($($incOpts.Count) configuration(s))" }

# b) SeggerRTT as source folder
$srcLists = $xml.SelectNodes("//sourceEntries")
foreach ($se in $srcLists) {
    $has = $se.SelectSingleNode("entry[@kind='sourcePath' and @name='SeggerRTT']")
    if (-not $has) {
        $e = $xml.CreateElement('entry')
        $e.SetAttribute('flags', 'VALUE_WORKSPACE_PATH|RESOLVED')
        $e.SetAttribute('kind', 'sourcePath')
        $e.SetAttribute('name', 'SeggerRTT')
        [void]$se.AppendChild($e)
        $changed = $true
    }
}
if ($srcLists.Count -eq 0) { Write-Warn2 "No <sourceEntries> found - right-click SeggerRTT > New > Source Folder in CubeIDE." }
else { Write-Ok "Source folder SeggerRTT ($($srcLists.Count) configuration(s))" }

# c) newlib-nano printf float support (only if the option already exists)
$fl = $xml.SelectNodes("//option[contains(@superClass,'option.nanoprintffloat')]")
foreach ($o in $fl) {
    if ($o.GetAttribute('value') -ne 'true') { $o.SetAttribute('value', 'true'); $changed = $true }
}
if ($fl.Count -gt 0) { Write-Ok "printf float support enabled ($($fl.Count) configuration(s))" }
else { Write-Skip "printf float: tick 'Use float with printf from newlib-nano' manually if you need %f" }

if ($changed) {
    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Encoding = $Utf8NoBom
    $settings.Indent = $false
    $w = [System.Xml.XmlWriter]::Create($cprojPath, $settings)
    try { $xml.Save($w) } finally { $w.Close() }
    Write-Ok ".cproject saved"
} else {
    Write-Skip ".cproject already up to date"
}

# ---------------------------------------------------------------------------
Write-Step "Patching Core\Src\main.c (USER CODE sections only)"
# ---------------------------------------------------------------------------
if ($NoMainPatch) {
    Write-Skip "-NoMainPatch given"
} else {
    $src = Read-Text $MainC
    $nl = "`n"; if ($src -match "`r`n") { $nl = "`r`n" }

    function Add-After([string]$text, [string]$marker, [string[]]$lines, [string]$tag) {
        if ($text.Contains($tag)) { Write-Skip "$marker : already present"; return $text }
        $m = [regex]::Match($text, '(?m)^[ \t]*/\*\s*' + [regex]::Escape($marker) + '\s*\*/[^\r\n]*\r?\n')
        if (-not $m.Success) { Write-Warn2 "'$marker' not found in main.c - add the code manually"; return $text }
        $block = ($lines -join $nl) + $nl
        Write-Ok "$marker"
        return $text.Insert($m.Index + $m.Length, $block)
    }

    $src = Add-After $src 'USER CODE BEGIN Includes' @(
        '#include "rtt_log.h"   /* RTT_DEMO */'
    ) '#include "rtt_log.h"'

    $src = Add-After $src 'USER CODE BEGIN 2' @(
        '  /* RTT_DEMO_BANNER: first messages after clock + GPIO init */',
        '  LOG_INF("SEGGER RTT demo - STM32H723, SYSCLK = %lu MHz",',
        '          (unsigned long)(HAL_RCC_GetSysClockFreq() / 1000000UL));',
        '  printf("printf() is redirected to RTT channel 0\r\n");'
    ) 'RTT_DEMO_BANNER'

    $src = Add-After $src 'USER CODE BEGIN 3' @(
        '    /* RTT_DEMO_HEARTBEAT: one line per second, without blocking */',
        '    {',
        '      static uint32_t rttLastTick = 0U;',
        '      static uint32_t rttCount    = 0U;',
        '      if ((HAL_GetTick() - rttLastTick) >= 1000U)',
        '      {',
        '        rttLastTick = HAL_GetTick();',
        '        LOG_INF("Heartbeat %lu", (unsigned long)rttCount++);',
        '      }',
        '    }'
    ) 'RTT_DEMO_HEARTBEAT'

    Save-Text $MainC $src
}

# ---------------------------------------------------------------------------
Write-Step "Checking for an old printf retarget (duplicate _write)"
# ---------------------------------------------------------------------------
$dups = Get-ChildItem -Path (Join-Path $ProjectDir 'Core') -Recurse -Filter '*.c' -File |
        Where-Object { $_.Name -ne 'syscalls.c' } |
        Where-Object { (Read-Text $_.FullName) -match '(?m)^\s*int\s+_write\s*\(' }
if ($dups) {
    foreach ($f in $dups) {
        Write-Warn2 "$($f.Name) defines its own _write() - delete it (rtt_log.c provides _write), else: 'multiple definition of _write'."
    }
} else {
    Write-Ok "No duplicate retarget found"
}

# ---------------------------------------------------------------------------
Write-Step "Copying OpenOCD / terminal helpers to RTT_Tools"
# ---------------------------------------------------------------------------
$Tools = Join-Path $ProjectDir 'RTT_Tools'
New-Item -ItemType Directory -Force -Path (Join-Path $Tools 'openocd') | Out-Null
Copy-Item (Join-Path $PkgDir 'tools\*.bat') $Tools -Force
Copy-Item (Join-Path $PkgDir 'tools\openocd\*.cfg') (Join-Path $Tools 'openocd') -Force
Write-Ok "$Tools"

# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "DONE. Next steps:" -ForegroundColor Green
Write-Host "  1. Open STM32CubeIDE, right-click the project > Refresh, then Project > Clean + Build."
Write-Host "  2. Check Debug\*.map: _SEGGER_RTT must be at 0x2000xxxx."
Write-Host "  3. View the logs (see README.md):"
Write-Host "       a) Debug with 'ST-LINK (OpenOCD)' + user-defined script RTT_Tools\openocd\stm32h723_rtt.cfg"
Write-Host "       b) or flash/run, then RTT_Tools\start_rtt_openocd.bat"
Write-Host "     then RTT_Tools\open_putty_rtt.bat (or Tera Term / CubeIDE Terminal on localhost:19021)."
Write-Host "  Backup of the original files: $Backup"
