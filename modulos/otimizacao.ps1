# Aba "Otimização": atalhos para o projeto OTIMIZAR_WINDOWS (executar.ps1 / reverter.ps1).
# Cada botão abre uma janela própria do PowerShell (visível, sem -Wait) para acompanhar o log.
# O painel já roda elevado; os scripts herdam o admin. Nada é auto-elevado aqui.
#
# Argumentos espelham o menu do OTIMIZAR.cmd do projeto:
#   Simular -> executar.ps1 -Etapas 0145 -Maximo -WhatIf  (só simula, não aplica)
#   Seguro  -> executar.ps1 -Etapas 0145                  (ajustes sem perda de função)
#   Máximo  -> executar.ps1 -Etapas 0145 -Maximo          (inclui ajustes com perda de função)
#   Reverter-> reverter.ps1                               (desfaz tudo pelo estado.json)
# Etapas 0145 = diagnóstico, backup, ajustes, manutenção (pula limpeza e reparo, que levam horas).

function Add-AbaOtimizacao {
    param([Windows.Forms.TabControl]$tabs)

    $page = New-Object Windows.Forms.TabPage
    $page.Text = 'Otimização'
    $page.UseVisualStyleBackColor = $true
    $tabs.TabPages.Add($page)

    $projeto = 'C:\Users\[REMOVIDO]\Documents\VSCODE\GIT\OTIMIZAR_WINDOWS'
    $executar = Join-Path $projeto 'executar.ps1'
    $reverter = Join-Path $projeto 'reverter.ps1'
    $achou = (Test-Path $executar) -and (Test-Path $reverter)

    $titulo = New-Object Windows.Forms.Label
    $titulo.Text = 'Otimização do Windows (projeto OTIMIZAR_WINDOWS).'
    $titulo.SetBounds(15, 12, 400, 22)
    $page.Controls.Add($titulo)

    $aviso = New-Object Windows.Forms.Label
    $aviso.Text = 'ATENÇÃO: "Seguro" e "Máximo" aplicam ajustes reais que ainda NÃO foram ' +
                  'validados nesta máquina (só foram simulados). "Simular" é o caminho seguro; ' +
                  'rode-o primeiro e leia o log.'
    $aviso.ForeColor = [Drawing.Color]::DarkOrange
    $aviso.SetBounds(15, 40, 400, 70)
    $page.Controls.Add($aviso)

    # Botão padrão/destaque: Simular.
    $bSimular = New-Object Windows.Forms.Button
    $bSimular.Text = [char]0x25B6 + ' Simular (não altera nada)'
    $bSimular.SetBounds(15, 120, 400, 40)
    $bSimular.Font = New-Object Drawing.Font('Segoe UI', 10, [Drawing.FontStyle]::Bold)
    $bSimular.Enabled = $achou
    $page.Controls.Add($bSimular)

    $bSeguro = New-Object Windows.Forms.Button
    $bSeguro.Text = 'Seguro'
    $bSeguro.SetBounds(15, 170, 195, 36)
    $bSeguro.Enabled = $achou
    $page.Controls.Add($bSeguro)

    $bMaximo = New-Object Windows.Forms.Button
    $bMaximo.Text = 'Máximo'
    $bMaximo.SetBounds(220, 170, 195, 36)
    $bMaximo.Enabled = $achou
    $page.Controls.Add($bMaximo)

    $bReverter = New-Object Windows.Forms.Button
    $bReverter.Text = 'Reverter'
    $bReverter.SetBounds(15, 216, 400, 36)
    $bReverter.Enabled = $achou
    $page.Controls.Add($bReverter)

    $nota = New-Object Windows.Forms.Label
    $nota.Text = 'Cada botão abre uma janela própria com o log. Reinicie o PC ao terminar.'
    $nota.ForeColor = [Drawing.Color]::DimGray
    $nota.SetBounds(15, 262, 400, 40)
    $page.Controls.Add($nota)

    if (-not $achou) {
        $erro = New-Object Windows.Forms.Label
        $erro.Text = 'Projeto NÃO encontrado em ' + $projeto + '. Botões desativados.'
        $erro.ForeColor = [Drawing.Color]::Firebrick
        $erro.SetBounds(15, 302, 400, 44)
        $page.Controls.Add($erro)
    }

    # Abre o script em janela visível, sem -Wait (não trava a UI). Herda o admin do painel.
    $rodar = {
        param($script, $extra)
        $args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$script`"") + $extra
        Start-Process powershell.exe -ArgumentList $args
    }

    $bSimular.Add_Click({
        & $rodar $executar @('-Etapas', '0145', '-Maximo', '-WhatIf')
    }.GetNewClosure())

    $bSeguro.Add_Click({
        $r = [Windows.Forms.MessageBox]::Show(
            'Isto vai APLICAR ajustes reais no sistema (modo seguro, sem perda de função).' + [Environment]::NewLine +
            'Estes ajustes ainda não foram validados nesta máquina. Continuar?',
            'Otimizar - Seguro', 'YesNo', 'Warning')
        if ($r -eq 'Yes') { & $rodar $executar @('-Etapas', '0145') }
    }.GetNewClosure())

    $bMaximo.Add_Click({
        $r = [Windows.Forms.MessageBox]::Show(
            'Isto vai APLICAR ajustes reais no sistema (modo MÁXIMO, inclui perda de função: ' +
            'busca indexada, localização etc.).' + [Environment]::NewLine +
            'Estes ajustes ainda não foram validados nesta máquina. Continuar?',
            'Otimizar - Máximo', 'YesNo', 'Warning')
        if ($r -eq 'Yes') { & $rodar $executar @('-Etapas', '0145', '-Maximo') }
    }.GetNewClosure())

    $bReverter.Add_Click({
        & $rodar $reverter @()
    }.GetNewClosure())
}
