# Aba "Limpeza": botoes de limpeza de disco, cada um com confirmacao antes de apagar.
# O Label de status mostra quanto espaco foi liberado em C: (Get-PSDrive C antes/depois).
#
# SEGURANCA: so mexe em $env:TEMP, C:\Windows\Temp, C:\Windows\SoftwareDistribution\Download
# e na Lixeira. Nunca toca em nada fora disso.
# O painel ja roda elevado; este modulo herda o admin e nao se auto-eleva.

function Get-LivreC {
    # Espaco livre em C: em bytes. Get-PSDrive expoe .Free.
    return (Get-PSDrive C).Free
}

function Format-Espaco($bytes) {
    if ($bytes -lt 0) { $bytes = 0 }
    if ($bytes -ge 1GB) { return ('{0:N2} GB' -f ($bytes / 1GB)) }
    if ($bytes -ge 1MB) { return ('{0:N1} MB' -f ($bytes / 1MB)) }
    return ('{0:N0} KB' -f ($bytes / 1KB))
}

function Add-AbaLimpeza {
    param([Windows.Forms.TabControl]$tabs)

    $page = New-Object Windows.Forms.TabPage
    $page.Text = 'Limpeza'
    $page.UseVisualStyleBackColor = $true
    $tabs.TabPages.Add($page)

    $dica = New-Object Windows.Forms.Label
    $dica.Text = 'Cada acao pede confirmacao antes de apagar. Arquivos em uso sao pulados.'
    $dica.SetBounds(15, 10, 410, 22)
    $page.Controls.Add($dica)

    $status = New-Object Windows.Forms.Label
    $status.SetBounds(15, 300, 410, 50)
    $status.ForeColor = [Drawing.Color]::DimGray
    $status.Text = 'Pronto.'
    $page.Controls.Add($status)

    # Esvazia o CONTEUDO de uma pasta (nao a pasta em si). Arquivos em uso sao pulados.
    $limparConteudo = {
        param($pasta)
        if (Test-Path $pasta) {
            Get-ChildItem -LiteralPath $pasta -Force -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # --- Limpar Temp ---
    $bTemp = New-Object Windows.Forms.Button
    $bTemp.Text = 'Limpar Temp'
    $bTemp.SetBounds(15, 45, 195, 36)
    $page.Controls.Add($bTemp)
    $bTemp.Add_Click({
        $r = [Windows.Forms.MessageBox]::Show(
            "Apagar o conteudo de:" + [Environment]::NewLine +
            $env:TEMP + [Environment]::NewLine +
            "C:\Windows\Temp" + [Environment]::NewLine + [Environment]::NewLine +
            "Continuar?",
            'Limpar Temp', 'YesNo', 'Warning')
        if ($r -ne 'Yes') { return }
        try {
            $antes = Get-LivreC
            & $limparConteudo $env:TEMP
            & $limparConteudo 'C:\Windows\Temp'
            $lib = (Get-LivreC) - $antes
            $status.ForeColor = [Drawing.Color]::ForestGreen
            $status.Text = "Temp limpo. Liberado: $(Format-Espaco $lib)."
        } catch {
            $status.ForeColor = [Drawing.Color]::Firebrick
            $status.Text = "Falha ao limpar Temp: $($_.Exception.Message)"
        }
    }.GetNewClosure())

    # --- Cache do Windows Update ---
    $bWU = New-Object Windows.Forms.Button
    $bWU.Text = 'Cache do Windows Update'
    $bWU.SetBounds(225, 45, 200, 36)
    $page.Controls.Add($bWU)
    $bWU.Add_Click({
        $r = [Windows.Forms.MessageBox]::Show(
            "Parar wuauserv e bits, apagar o cache de downloads do Windows Update" + [Environment]::NewLine +
            "(C:\Windows\SoftwareDistribution\Download) e reiniciar os servicos." + [Environment]::NewLine + [Environment]::NewLine +
            "Continuar?",
            'Cache do Windows Update', 'YesNo', 'Warning')
        if ($r -ne 'Yes') { return }
        try {
            $antes = Get-LivreC
            Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
            Stop-Service bits -Force -ErrorAction SilentlyContinue
            & $limparConteudo 'C:\Windows\SoftwareDistribution\Download'
            Start-Service wuauserv -ErrorAction SilentlyContinue
            Start-Service bits -ErrorAction SilentlyContinue
            $lib = (Get-LivreC) - $antes
            $status.ForeColor = [Drawing.Color]::ForestGreen
            $status.Text = "Cache do Windows Update limpo. Liberado: $(Format-Espaco $lib)."
        } catch {
            $status.ForeColor = [Drawing.Color]::Firebrick
            $status.Text = "Falha no cache do Windows Update: $($_.Exception.Message)"
        }
    }.GetNewClosure())

    # --- Esvaziar Lixeira ---
    $bLixo = New-Object Windows.Forms.Button
    $bLixo.Text = 'Esvaziar Lixeira'
    $bLixo.SetBounds(15, 90, 195, 36)
    $page.Controls.Add($bLixo)
    $bLixo.Add_Click({
        $r = [Windows.Forms.MessageBox]::Show(
            "Esvaziar a Lixeira de todas as unidades?",
            'Esvaziar Lixeira', 'YesNo', 'Warning')
        if ($r -ne 'Yes') { return }
        try {
            $antes = Get-LivreC
            Clear-RecycleBin -Force -ErrorAction SilentlyContinue
            $lib = (Get-LivreC) - $antes
            $status.ForeColor = [Drawing.Color]::ForestGreen
            $status.Text = "Lixeira esvaziada. Liberado: $(Format-Espaco $lib)."
        } catch {
            $status.ForeColor = [Drawing.Color]::Firebrick
            $status.Text = "Falha ao esvaziar a Lixeira: $($_.Exception.Message)"
        }
    }.GetNewClosure())

    # --- DISM Component Cleanup ---
    $bDism = New-Object Windows.Forms.Button
    $bDism.Text = 'DISM Component Cleanup'
    $bDism.SetBounds(225, 90, 200, 36)
    $page.Controls.Add($bDism)
    $bDism.Add_Click({
        $r = [Windows.Forms.MessageBox]::Show(
            "Rodar DISM /StartComponentCleanup para limpar componentes antigos do Windows." + [Environment]::NewLine +
            "Demora alguns minutos e abre em janela propria." + [Environment]::NewLine + [Environment]::NewLine +
            "Continuar?",
            'DISM Component Cleanup', 'YesNo', 'Warning')
        if ($r -ne 'Yes') { return }
        try {
            # Sem -Wait: a limpeza roda na janela propria do DISM sem travar o painel.
            Start-Process dism.exe -ArgumentList '/Online /Cleanup-Image /StartComponentCleanup'
            $status.ForeColor = [Drawing.Color]::DimGray
            $status.Text = 'DISM rodando em janela propria. Pode demorar; acompanhe por la.'
        } catch {
            $status.ForeColor = [Drawing.Color]::Firebrick
            $status.Text = "Falha ao iniciar o DISM: $($_.Exception.Message)"
        }
    }.GetNewClosure())
}
