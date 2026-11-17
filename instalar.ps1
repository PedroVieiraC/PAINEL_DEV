# Instalador do Painel Dev. Copie ESTE arquivo para o lado do .zip (fora do zip) e rode:
#   clique direito > Executar com o PowerShell   (ele pede administrador sozinho)
# Ordem: 1) exclui defender-control\ no Defender, 2) so entao extrai o zip.
# Extrair antes (ou pelo Explorer) faz o Defender por os .exe em quarentena.
param([string]$Zip, [string]$Destino = $PSScriptRoot)

$ehAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $ehAdmin) {
    $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Destino', "`"$Destino`"")
    if ($Zip) { $a += @('-Zip', "`"$Zip`"") }
    Start-Process powershell -Verb RunAs -ArgumentList $a
    return
}

try {
    if (-not $Zip) { $Zip = (Get-ChildItem $PSScriptRoot -Filter *.zip | Select-Object -First 1).FullName }
    if (-not $Zip -or -not (Test-Path $Zip)) { throw 'Nenhum .zip encontrado ao lado do instalar.ps1.' }

    # Pasta raiz dentro do zip (o nome da pasta zipada), para saber qual caminho excluir.
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $z = [IO.Compression.ZipFile]::OpenRead($Zip)
    $raizZip = ($z.Entries[0].FullName -split '[\\/]')[0]
    $z.Dispose()

    $pasta = Join-Path (Join-Path $Destino $raizZip) 'defender-control'
    Write-Host "Excluindo do Defender: $pasta"
    Add-MpPreference -ExclusionPath $pasta -ErrorAction Stop
    if ((Get-MpPreference).ExclusionPath -notcontains $pasta) { throw 'A exclusao nao foi aplicada (Protecao contra Adulteracao ligada?).' }

    Write-Host "Extraindo $Zip em $Destino"
    Expand-Archive -Path $Zip -DestinationPath $Destino -Force
    Write-Host 'Pronto.' -ForegroundColor Green
}
catch { Write-Host "ERRO: $($_.Exception.Message)" -ForegroundColor Red }
Read-Host 'Enter para fechar'
