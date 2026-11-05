<#
.SYNOPSIS
    Trae las mejoras del autor (ajaquin8/autocad-mcp) a la rama ss-main sin pisar tus cambios.

.DESCRIPTION
    Sin parámetros solo informa: baja lo nuevo del autor, actualiza la copia "main" y muestra
    qué versiones y commits del autor todavía no están en ss-main. No cambia ss-main.

    -Merge <ref>  une una versión del autor en ss-main con un merge (nunca rebase: tus commits
                  quedan como están). <ref> es un tag (v0.1.3) o upstream/main. Si hay
                  conflictos se detiene y explica cómo seguir o cancelar.
    -Push         sube main y ss-main a tu fork (origin). Al autor (upstream) nunca se sube nada.

    Revisá siempre lo que trae una versión antes de unirla: el informe muestra los commits y
    "git diff ss-main <ref>" muestra el código.

.EXAMPLE
    .\update.cmd
    .\update.cmd -Merge v0.1.3
    .\update.cmd -Merge v0.1.3 -Push
#>
param(
    [string]$Merge = "",
    [switch]$Push
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Invoke-Git {
    & git @args
    if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') falló (código $LASTEXITCODE)." }
}

function Get-GitLines {
    $out = & git @args
    if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') falló (código $LASTEXITCODE)." }
    $out | Where-Object { $_ }
}

# ---------- comprobaciones ----------
$branch = @(Get-GitLines rev-parse --abbrev-ref HEAD)[0]
if ($branch -ne "ss-main") {
    throw "Estás en la rama '$branch'. Cambiá a ss-main (git switch ss-main) y volvé a correr el script."
}
if (Get-GitLines status --porcelain) {
    throw "Hay cambios sin commit en la carpeta. Hacé commit (o descartalos) antes de actualizar."
}

# ---------- bajar lo nuevo ----------
Write-Host "Bajando novedades del autor (upstream) y de tu fork (origin)..." -ForegroundColor Cyan
Invoke-Git fetch upstream --tags --prune --quiet
Invoke-Git fetch origin --prune --quiet
# main es solo una copia del main del autor: avanza si puede; si alguien hizo commits ahí, avisa.
& git fetch upstream main:main --quiet 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Warning "La rama local 'main' tiene commits propios y no sigue al autor. Tus cambios van en ss-main."
}

# ---------- informe ----------
$tags = @(Get-GitLines tag --no-merged ss-main --sort=-v:refname --list "v*")
$theirs = @(Get-GitLines log --oneline ss-main..upstream/main)
$mine = @(Get-GitLines log --oneline --no-merges upstream/main..ss-main)
$installed = @(Get-GitLines rev-parse --short ss-main)[0]

Write-Host ""
Write-Host "ss-main está en $installed. Versiones del autor que todavía no tiene:" -ForegroundColor Cyan
if ($tags) { $tags | ForEach-Object { Write-Host "  $_" } } else { Write-Host "  (ninguna)" }
Write-Host ""
Write-Host "Commits del autor en main que no están en ss-main: $($theirs.Count)" -ForegroundColor Cyan
$theirs | Select-Object -First 15 | ForEach-Object { Write-Host "  $_" }
if ($theirs.Count -gt 15) { Write-Host "  ... y $($theirs.Count - 15) más (git log ss-main..upstream/main)" }
Write-Host ""
Write-Host "Tus commits propios en ss-main: $($mine.Count)" -ForegroundColor Cyan
$mine | Select-Object -First 15 | ForEach-Object { Write-Host "  $_" }

# ---------- unir una versión ----------
if ($Merge) {
    & git rev-parse --verify --quiet "$Merge^{commit}" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "No existe '$Merge'. Usá un tag de la lista (por ejemplo v0.1.3) o upstream/main." }
    $before = @(Get-GitLines rev-parse --short HEAD)[0]
    Write-Host ""
    Write-Host "Uniendo $Merge en ss-main (merge, tus commits no se reescriben)..." -ForegroundColor Cyan
    & git merge --no-ff --no-edit -m "Traer $Merge del autor a ss-main" $Merge
    if ($LASTEXITCODE -ne 0) {
        $conflicts = @(Get-GitLines diff --name-only --diff-filter=U)
        Write-Host ""
        Write-Warning "El merge se detuvo por conflictos en:"
        $conflicts | ForEach-Object { Write-Host "  $_" }
        Write-Host ""
        Write-Host "Para seguir: resolvé esos archivos, después 'git add <archivo>' y 'git commit'."
        Write-Host "Para cancelar y dejar ss-main como estaba: git merge --abort"
        exit 1
    }
    $after = @(Get-GitLines rev-parse --short HEAD)[0]
    if ($after -eq $before) {
        Write-Host "ss-main ya tenía $Merge; no hubo cambios." -ForegroundColor Green
    } else {
        Write-Host "Listo: ss-main pasó de $before a $after." -ForegroundColor Green
        Write-Host "Archivos cambiados:"
        Get-GitLines diff --stat "$before" "$after" | ForEach-Object { Write-Host "  $_" }
    }
}

# ---------- subir a tu fork ----------
if ($Push) {
    Write-Host ""
    Write-Host "Subiendo main y ss-main a tu fork (origin)..." -ForegroundColor Cyan
    Invoke-Git push origin main ss-main
}

$head = @(Get-GitLines rev-parse HEAD)[0]
Write-Host ""
Write-Host "Para que Claude Code use esta versión de ss-main, el servidor se fija a este commit:" -ForegroundColor Cyan
Write-Host "  git+https://github.com/segninimora-source/autocad-mcp@$head"
Write-Host "(antes hay que subirla con -Push; el cambio de configuración se hace con tu OK)."
