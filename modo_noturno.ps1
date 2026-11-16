# Modo noturno: marca o que aplicar e clica Executar. Desmarcado volta ao valor original.
$ErrorActionPreference = 'Stop'

# Precisa de administrador para a política do Windows Update e a ação da tampa.
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    exit
}

Add-Type -AssemblyName System.Windows.Forms
$estadoPath = Join-Path $PSScriptRoot 'estado.json'
$auKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'

# Valor = o que o modo noturno aplica (segundos; tampa 0 = não fazer nada).
$itens = @(
    @{ Id = 'Suspensao';  Texto = 'Não suspender (tomada e bateria)';      Sub = 'SUB_SLEEP'; Set = 'STANDBYIDLE';   Valor = 0 }
    @{ Id = 'Hibernacao'; Texto = 'Não hibernar';                           Sub = 'SUB_SLEEP'; Set = 'HIBERNATEIDLE'; Valor = 0 }
    @{ Id = 'Tampa';      Texto = 'Tampa fechada: não fazer nada';          Sub = '4f971e89-eebd-4455-a8de-9e59040e7347'; Set = '5ca83367-6e45-459f-a27b-476b1d01c936'; Valor = 0 }
    @{ Id = 'Tela';       Texto = 'Apagar a tela em 5 min';                 Sub = 'SUB_VIDEO'; Set = 'VIDEOIDLE';     Valor = 300 }
    @{ Id = 'Update';     Texto = 'Impedir reinício automático do Windows Update' }
)

function Ler-Power($item) {
    $hex = [regex]::Matches((powercfg /query SCHEME_CURRENT $item.Sub $item.Set) -join "`n", '0x([0-9a-fA-F]+)') | ForEach-Object { [Convert]::ToInt64($_.Groups[1].Value, 16) }
    # shortcut: configuração oculta (tampa) não aparece no /query; assume o padrão do Windows (1 = suspender).
    if ($hex.Count -lt 2) { return @{ ac = 1; dc = 1 } }
    # As duas últimas são o valor atual na tomada (AC) e na bateria (DC).
    return @{ ac = $hex[-2]; dc = $hex[-1] }
}

function Gravar-Power($item, $ac, $dc) {
    powercfg /setacvalueindex SCHEME_CURRENT $item.Sub $item.Set $ac
    powercfg /setdcvalueindex SCHEME_CURRENT $item.Sub $item.Set $dc
    powercfg /setactive SCHEME_CURRENT
}

function Ler-Update {
    $v = (Get-ItemProperty $auKey -ErrorAction SilentlyContinue).NoAutoRebootWithLoggedOnUsers
    return @{ valor = $v }
}

function Gravar-Update($valor) {
    if ($null -eq $valor) {
        Remove-ItemProperty $auKey -Name NoAutoRebootWithLoggedOnUsers -ErrorAction SilentlyContinue
    } else {
        if (-not (Test-Path $auKey)) { New-Item $auKey -Force | Out-Null }
        Set-ItemProperty $auKey -Name NoAutoRebootWithLoggedOnUsers -Value $valor -Type DWord
    }
}

# Estado: guarda o valor original de cada item aplicado. Item presente = modo noturno ativo nele.
$estado = @{}
if (Test-Path $estadoPath) {
    $json = Get-Content $estadoPath -Raw | ConvertFrom-Json
    foreach ($p in $json.PSObject.Properties) {
        $h = @{}
        foreach ($q in $p.Value.PSObject.Properties) { $h[$q.Name] = $q.Value }
        $estado[$p.Name] = $h
    }
}

$form = New-Object Windows.Forms.Form
$form.Text = 'Modo noturno'
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.ClientSize = New-Object Drawing.Size(380, 280)
$form.Font = New-Object Drawing.Font('Segoe UI', 10)

$dica = New-Object Windows.Forms.Label
$dica.Text = 'Marcado = aplicar. Desmarcado = voltar ao original.'
$dica.SetBounds(15, 10, 350, 22)
$form.Controls.Add($dica)

$caixas = @{}
$y = 40
foreach ($item in $itens) {
    $cb = New-Object Windows.Forms.CheckBox
    $cb.Text = $item.Texto
    $cb.Checked = $estado.ContainsKey($item.Id)
    $cb.SetBounds(15, $y, 350, 26)
    $form.Controls.Add($cb)
    $caixas[$item.Id] = $cb
    $y += 30
}

$status = New-Object Windows.Forms.Label
$status.SetBounds(15, 240, 230, 30)
$status.ForeColor = [Drawing.Color]::DimGray
$form.Controls.Add($status)

$botao = New-Object Windows.Forms.Button
$botao.Text = [char]0x25B6 + ' Executar'
$botao.SetBounds(255, 235, 110, 34)
$form.Controls.Add($botao)
$form.AcceptButton = $botao

$botao.Add_Click({
    try {
        foreach ($item in $itens) {
            $marcado = $caixas[$item.Id].Checked
            $ativo = $estado.ContainsKey($item.Id)
            if ($marcado -and -not $ativo) {
                if ($item.Id -eq 'Update') {
                    $estado[$item.Id] = Ler-Update
                    Gravar-Update 1
                } else {
                    $orig = Ler-Power $item
                    # shortcut: suspensão já em 0 (start_project rodou antes) volta para 30 min, como o stop_project.
                    if ($item.Id -eq 'Suspensao') { foreach ($k in 'ac', 'dc') { if ($orig[$k] -eq 0) { $orig[$k] = 1800 } } }
                    $estado[$item.Id] = $orig
                    Gravar-Power $item $item.Valor $item.Valor
                }
            } elseif (-not $marcado -and $ativo) {
                $orig = $estado[$item.Id]
                if ($item.Id -eq 'Update') { Gravar-Update $orig.valor } else { Gravar-Power $item $orig.ac $orig.dc }
                $estado.Remove($item.Id)
            }
        }
        $estado | ConvertTo-Json | Set-Content $estadoPath -Encoding UTF8
        $n = $estado.Count
        $status.Text = if ($n) { "Modo noturno ativo em $n item(ns)." } else { 'Tudo no valor original.' }
    } catch {
        [Windows.Forms.MessageBox]::Show("Falhou: $($_.Exception.Message)", 'Modo noturno') | Out-Null
    }
})

$status.Text = if ($estado.Count) { "Modo noturno ativo em $($estado.Count) item(ns)." } else { 'Tudo no valor original.' }
[void]$form.ShowDialog()
