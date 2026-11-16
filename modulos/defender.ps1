# Aba "Windows Defender": lugar preparado para integrar o Defender Control (etapa 2).
# Os executaveis estao em <raiz>\defender-control\. NADA e executado aqui ainda -
# esta etapa so monta a aba e detecta os .exe. A chamada real entra na proxima etapa.

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
    $nota.SetBounds(15, 125, 385, 70)
    $page.Controls.Add($nota)

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
