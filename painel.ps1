# Painel Dev - janela principal. Cada funcionalidade e uma aba carregada de modulos\*.ps1.
#
# Para adicionar uma funcionalidade nova:
#   1. crie modulos\<nome>.ps1 com uma funcao Add-Aba<Nome> ($tabs)
#   2. acrescente duas linhas iguais as de baixo (dot-source + chamada)
$ErrorActionPreference = 'Stop'

# Elevacao UNICA: o painel inteiro roda como administrador e cada modulo herda isso.
# Nenhum modulo deve chamar RunAs por conta propria.
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object Windows.Forms.Form
$form.Text = 'Painel Dev'
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'Sizable'
$form.MaximizeBox = $true
$form.ClientSize = New-Object Drawing.Size(470, 420)
$form.MinimumSize = New-Object Drawing.Size(486, 460)   # nao deixa encolher abaixo do conteudo
$form.Font = New-Object Drawing.Font('Segoe UI', 10)

$tabs = New-Object Windows.Forms.TabControl
$tabs.Dock = 'Fill'
$form.Controls.Add($tabs)   # precisa estar no form antes dos modulos (eles usam $tabs.FindForm())

# --- Abas ---
. (Join-Path $PSScriptRoot 'modulos\energia.ps1');    Add-AbaEnergia    $tabs
. (Join-Path $PSScriptRoot 'modulos\sistema.ps1');    Add-AbaSistema    $tabs
. (Join-Path $PSScriptRoot 'modulos\limpeza.ps1');    Add-AbaLimpeza    $tabs
. (Join-Path $PSScriptRoot 'modulos\rede.ps1');       Add-AbaRede       $tabs
. (Join-Path $PSScriptRoot 'modulos\dev.ps1');        Add-AbaDev        $tabs
. (Join-Path $PSScriptRoot 'modulos\otimizacao.ps1'); Add-AbaOtimizacao $tabs
. (Join-Path $PSScriptRoot 'modulos\defender.ps1');   Add-AbaDefender   $tabs

# --- Menu (navbar) no topo ---
$script:PainelPath = $PSCommandPath   # capturado para o "Reiniciar painel"
$script:PainelDir  = $PSScriptRoot
$menu = New-Object Windows.Forms.MenuStrip

$mPainel = New-Object Windows.Forms.ToolStripMenuItem 'Painel'
$miReiniciar = $mPainel.DropDownItems.Add('Reiniciar painel')
$miReiniciar.Add_Click({
    # Abre uma instancia nova (ja elevada, por ser filha deste processo admin) e fecha esta.
    Start-Process powershell.exe -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',('"' + $script:PainelPath + '"')
    $form.Close()
})
$miPasta = $mPainel.DropDownItems.Add('Abrir pasta do painel')
$miPasta.Add_Click({ Start-Process explorer.exe $script:PainelDir })
[void]$mPainel.DropDownItems.Add((New-Object Windows.Forms.ToolStripSeparator))
$miSair = $mPainel.DropDownItems.Add('Sair')
$miSair.Add_Click({ $form.Close() })
[void]$menu.Items.Add($mPainel)

$mJanela = New-Object Windows.Forms.ToolStripMenuItem 'Janela'
$miTopo = $mJanela.DropDownItems.Add('Sempre no topo')
$miTopo.Add_Click({ $form.TopMost = -not $form.TopMost; $miTopo.Checked = $form.TopMost })
[void]$menu.Items.Add($mJanela)

$form.Controls.Add($menu)
$form.MainMenuStrip = $menu
$tabs.BringToFront()   # o controle Fill fica na frente do z-order p/ nao ficar sob o menu

# Abas em linha unica: quando estouram a largura, o TabControl mostra as setas de rolagem
# e rola para a aba selecionada (limitado, sem dar a volta).
$tabs.Multiline = $false

[void]$form.ShowDialog()
