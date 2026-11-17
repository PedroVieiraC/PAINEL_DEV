# Aba "Windows Defender": lugar preparado para integrar o Defender Control (etapa 2).
# Os executaveis estao em <raiz>\defender-control\. NADA e executado aqui ainda -
# esta etapa so monta a aba e detecta os .exe. A chamada real entra na proxima etapa.

# --- Exclusao do Defender para defender-control\ (os .exe sao detectados como HackTool) ---
function Get-PastaDefenderControl { Join-Path (Split-Path $PSScriptRoot -Parent) 'defender-control' }

function Test-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Retorna $true/$false, ou $null se nao der para consultar.
function Get-ExclusaoDefenderAtiva {
    try { return [bool]((Get-MpPreference -ErrorAction Stop).ExclusionPath -contains (Get-PastaDefenderControl)) }
    catch { return $null }
}

# acao: 'add' | 'remove' | 'status'. Mostra o resultado em MessageBox.
function Invoke-ExclusaoDefender {
    param([ValidateSet('add', 'remove', 'status')][string]$acao)
    $pasta = Get-PastaDefenderControl
    $titulo = 'Exclusao do Defender'
    if (-not (Test-Admin)) {
        [Windows.Forms.MessageBox]::Show('Esta acao exige administrador. Feche o painel e abra-o como administrador.', $titulo, 'OK', 'Warning') | Out-Null
        return
    }
    try {
        if ($acao -eq 'add') {
            $r = [Windows.Forms.MessageBox]::Show("Excluir esta pasta da varredura REDUZ a protecao do Windows Defender:`n$pasta`n`nContinuar?", $titulo, 'YesNo', 'Warning')
            if ($r -ne 'Yes') { return }
            Add-MpPreference -ExclusionPath $pasta -ErrorAction Stop
        }
        elseif ($acao -eq 'remove') { Remove-MpPreference -ExclusionPath $pasta -ErrorAction Stop }
        $ativa = Get-ExclusaoDefenderAtiva
        $txt = if ($null -eq $ativa) { 'Nao foi possivel consultar o Defender.' } elseif ($ativa) { 'Exclusao: ATIVA' } else { 'Exclusao: INATIVA' }
        [Windows.Forms.MessageBox]::Show("$txt`n$pasta", $titulo, 'OK', 'Information') | Out-Null
    }
    catch {
        [Windows.Forms.MessageBox]::Show("Falhou: $($_.Exception.Message)", $titulo, 'OK', 'Error') | Out-Null
    }
}

function Add-AbaDefender {
    param([Windows.Forms.TabControl]$tabs)

    $page = New-Object Windows.Forms.TabPage
    $page.Text = 'Windows Defender'
    $page.UseVisualStyleBackColor = $true
    $tabs.TabPages.Add($page)

    $raiz = Split-Path $PSScriptRoot -Parent
    $exeDisable = Join-Path $raiz 'defender-control\disable-defender.exe'
    $exeEnable  = Join-Path $raiz 'defender-control\enable-defender.exe'
    $achou = (Test-Path $exeDisable) -and (Test-Path $exeEnable)

    $lbl = New-Object Windows.Forms.Label
    $lbl.Text = 'Controle do Windows Defender (em preparacao).'
    $lbl.SetBounds(15, 12, 380, 22)
    $page.Controls.Add($lbl)

    $st = New-Object Windows.Forms.Label
    $st.Text = if ($achou) { 'Executaveis encontrados em defender-control\.' } else { 'Executaveis NAO encontrados em defender-control\.' }
    $st.ForeColor = if ($achou) { [Drawing.Color]::ForestGreen } else { [Drawing.Color]::Firebrick }
    $st.SetBounds(15, 40, 380, 22)
    $page.Controls.Add($st)

    # Botoes so ficam ativos se os .exe existirem.
    $bDesativar = New-Object Windows.Forms.Button
    $bDesativar.Text = 'Desativar Defender'
    $bDesativar.SetBounds(15, 80, 165, 34)
    $bDesativar.Enabled = $achou
    $page.Controls.Add($bDesativar)

    $bReativar = New-Object Windows.Forms.Button
    $bReativar.Text = 'Reativar Defender'
    $bReativar.SetBounds(190, 80, 165, 34)
    $bReativar.Enabled = $achou
    $page.Controls.Add($bReativar)

    $nota = New-Object Windows.Forms.Label
    $nota.Text = 'Abre em janela propria com o log completo. Desativar pede reboot para concluir.'
    $nota.ForeColor = [Drawing.Color]::DimGray
    $nota.SetBounds(15, 125, 385, 40)
    $page.Controls.Add($nota)

    # Exclusao da pasta defender-control\ no Defender (exige admin; aviso de risco ao adicionar).
    $grp = New-Object Windows.Forms.GroupBox
    $grp.Text = 'Exclusao de defender-control\ (evita quarentena dos .exe)'
    $grp.SetBounds(15, 170, 385, 105)
    $page.Controls.Add($grp)

    $acoes = @(
        @('Adicionar', 'add', 10), @('Remover', 'remove', 130), @('Status', 'status', 250))
    foreach ($a in $acoes) {
        $b = New-Object Windows.Forms.Button
        $b.Text = $a[0]
        $b.SetBounds($a[2], 25, 115, 30)
        $acao = $a[1]
        $b.Add_Click({ Invoke-ExclusaoDefender $acao }.GetNewClosure())
        $grp.Controls.Add($b)
    }

    $aviso = New-Object Windows.Forms.Label
    $aviso.Text = 'Aviso: excluir essa pasta reduz a protecao do Defender. Exige administrador.'
    $aviso.ForeColor = [Drawing.Color]::Firebrick
    $aviso.SetBounds(10, 62, 365, 36)
    $grp.Controls.Add($aviso)

    # Sem -ArgumentList '-s': deixamos o exe mostrar o console e pausar no fim, para
    # voce ler o resultado. O painel ja esta elevado, entao o exe herda o admin (e ele
    # mesmo sobe para TrustedInstaller por dentro). Sem -Wait: a janela do painel nao trava.
    $bDesativar.Add_Click({
        $r = [Windows.Forms.MessageBox]::Show(
            "Isto vai DESATIVAR o Windows Defender (antivirus, firewall, SmartScreen, etc.)." + [Environment]::NewLine +
            "Conclui apos reiniciar. Continuar?",
            'Desativar Defender', 'YesNo', 'Warning')
        if ($r -eq 'Yes') { Start-Process $exeDisable }
    }.GetNewClosure())

    $bReativar.Add_Click({
        Start-Process $exeEnable
    }.GetNewClosure())
}
