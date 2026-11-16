# Aba "Manter Acordado" (antigo "Modo noturno").
# Impede suspensao/hibernacao/apagar-tela e o reinicio automatico do Windows Update
# enquanto um trabalho longo roda. Marcado = aplicar; desmarcado = voltar ao valor original.

# estado.json fica na RAIZ do painel (uma pasta acima de modulos\).
$script:EnergiaEstadoPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'estado.json'
$script:EnergiaAuKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'

# Valor = o que o modo aplica (segundos; tampa/suspensao 0 = nao fazer nada).
$script:EnergiaItens = @(
    @{ Id = 'Suspensao';  Texto = 'Nao suspender (tomada e bateria)';     Sub = 'SUB_SLEEP'; Set = 'STANDBYIDLE';   Valor = 0 }
    @{ Id = 'Hibernacao'; Texto = 'Nao hibernar';                          Sub = 'SUB_SLEEP'; Set = 'HIBERNATEIDLE'; Valor = 0 }
    @{ Id = 'Tampa';      Texto = 'Tampa fechada: nao fazer nada';         Sub = '4f971e89-eebd-4455-a8de-9e59040e7347'; Set = '5ca83367-6e45-459f-a27b-476b1d01c936'; Valor = 0 }
    @{ Id = 'Tela';       Texto = 'Apagar a tela em 5 min';               Sub = 'SUB_VIDEO'; Set = 'VIDEOIDLE';     Valor = 300 }
    @{ Id = 'Update';     Texto = 'Impedir reinicio automatico do Windows Update' }
)

function Ler-Power($item) {
    $hex = [regex]::Matches((powercfg /query SCHEME_CURRENT $item.Sub $item.Set) -join "`n", '0x([0-9a-fA-F]+)') | ForEach-Object { [Convert]::ToInt64($_.Groups[1].Value, 16) }
    # shortcut: configuracao oculta (tampa) nao aparece no /query; assume o padrao do Windows (1 = suspender).
    if ($hex.Count -lt 2) { return @{ ac = 1; dc = 1 } }
    # As duas ultimas sao o valor atual na tomada (AC) e na bateria (DC).
    return @{ ac = $hex[-2]; dc = $hex[-1] }
}

function Gravar-Power($item, $ac, $dc) {
    powercfg /setacvalueindex SCHEME_CURRENT $item.Sub $item.Set $ac
    powercfg /setdcvalueindex SCHEME_CURRENT $item.Sub $item.Set $dc
    powercfg /setactive SCHEME_CURRENT
}

function Ler-Update {
    $v = (Get-ItemProperty $script:EnergiaAuKey -ErrorAction SilentlyContinue).NoAutoRebootWithLoggedOnUsers
    return @{ valor = $v }
}

function Gravar-Update($valor) {
    if ($null -eq $valor) {
        Remove-ItemProperty $script:EnergiaAuKey -Name NoAutoRebootWithLoggedOnUsers -ErrorAction SilentlyContinue
    } else {
        if (-not (Test-Path $script:EnergiaAuKey)) { New-Item $script:EnergiaAuKey -Force | Out-Null }
        Set-ItemProperty $script:EnergiaAuKey -Name NoAutoRebootWithLoggedOnUsers -Value $valor -Type DWord
    }
}

function Add-AbaEnergia {
    param([Windows.Forms.TabControl]$tabs)

    $page = New-Object Windows.Forms.TabPage
    $page.Text = 'Manter Acordado'
    $page.UseVisualStyleBackColor = $true
    $tabs.TabPages.Add($page)
    $form = $tabs.FindForm()

    $itens = $script:EnergiaItens

    # Estado: guarda o valor original de cada item aplicado. Item presente = modo ativo nele.
    $estado = @{}
    if (Test-Path $script:EnergiaEstadoPath) {
        $json = Get-Content $script:EnergiaEstadoPath -Raw | ConvertFrom-Json
        foreach ($p in $json.PSObject.Properties) {
            $h = @{}
            foreach ($q in $p.Value.PSObject.Properties) { $h[$q.Name] = $q.Value }
            $estado[$p.Name] = $h
        }
    }

    $dica = New-Object Windows.Forms.Label
    $dica.Text = 'Marcado = aplicar. Desmarcado = voltar ao original.'
    $dica.SetBounds(15, 10, 360, 22)
    $page.Controls.Add($dica)

    $caixas = @{}
    $y = 40
    foreach ($item in $itens) {
        $cb = New-Object Windows.Forms.CheckBox
        $cb.Text = $item.Texto
        $cb.Checked = $estado.ContainsKey($item.Id)
        $cb.SetBounds(15, $y, 360, 26)
        $page.Controls.Add($cb)
        $caixas[$item.Id] = $cb
        $y += 30
    }

    $status = New-Object Windows.Forms.Label
    $status.SetBounds(15, 245, 240, 30)
    $status.ForeColor = [Drawing.Color]::DimGray
    $page.Controls.Add($status)

    $botao = New-Object Windows.Forms.Button
    $botao.Text = [char]0x25B6 + ' Executar'
    $botao.SetBounds(270, 240, 110, 34)
    $page.Controls.Add($botao)
    if ($form) { $form.AcceptButton = $botao }

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
                        # shortcut: suspensao ja em 0 (start_project rodou antes) volta para 30 min, como o stop_project.
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
            $estado | ConvertTo-Json | Set-Content $script:EnergiaEstadoPath -Encoding UTF8
            $n = $estado.Count
            $status.Text = if ($n) { "Ativo em $n item(ns)." } else { 'Tudo no valor original.' }
        } catch {
            [Windows.Forms.MessageBox]::Show("Falhou: $($_.Exception.Message)", 'Manter Acordado') | Out-Null
        }
    }.GetNewClosure())

    $status.Text = if ($estado.Count) { "Ativo em $($estado.Count) item(ns)." } else { 'Tudo no valor original.' }
}
