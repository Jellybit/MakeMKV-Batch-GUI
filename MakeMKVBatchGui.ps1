# Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# --- Configuration ---
$script:PathDelimiter = "|||"
$script:Runspace = $null
$script:PowerShell = $null

# --- Helpers ---
function Show-MessageBox {
    param ([string]$Message, [string]$Title = "MKVMerge Batcher", [string]$Type = "Info")
    $image   = switch ($Type) { "Error" { "Error" } "Warning" { "Warning" } "Question" { "Question" } default { "Information" } }
    $buttons = if ($Type -eq "Question") { "YesNo" } else { "OK" }
    return [System.Windows.MessageBox]::Show($script:Window, $Message, $Title, $buttons, $image)
}

function Get-SelectedPaths {
    param ($InputString)
    if ([string]::IsNullOrWhiteSpace($InputString)) { return @() }
    if ($InputString -like "*$($script:PathDelimiter)*") {
        return @($InputString -split [regex]::Escape($script:PathDelimiter) | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
    }
    if (Test-Path $InputString -PathType Container) {
        return @(Get-ChildItem -LiteralPath $InputString | Where-Object { !$_.PSIsContainer } | Select-Object -ExpandProperty FullName)
    }
    return @($InputString)
}

function Update-DefaultOutput {
    param($FirstPath)
    if ([string]::IsNullOrWhiteSpace($C.TxtOutput.Text) -and ![string]::IsNullOrWhiteSpace($FirstPath)) {
        try {
            $parent = if (Test-Path $FirstPath -PathType Container) { $FirstPath } else { Split-Path $FirstPath -Parent }
            $C.TxtOutput.Text = Join-Path $parent "_output"
        } catch {}
    }
}

function Browse-Files {
    param ($TextBox, [switch]$UpdateOutput)
    $d = New-Object System.Windows.Forms.OpenFileDialog
    $d.Multiselect = $true
    if ($d.ShowDialog() -eq "OK") {
        $TextBox.Text = $d.FileNames -join $script:PathDelimiter
        if ($UpdateOutput) { Update-DefaultOutput -FirstPath $d.FileNames[0] }
    }
}

function Browse-Folder {
    param ($TextBox, [switch]$UpdateOutput)
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($d.ShowDialog() -eq "OK") {
        $TextBox.Text = $d.SelectedPath
        if ($UpdateOutput) { Update-DefaultOutput -FirstPath $d.SelectedPath }
    }
}

function Stop-BackgroundWork {
    try { if ($script:PowerShell) { $script:PowerShell.Stop(); $script:PowerShell.Dispose() } } catch {}
    try { if ($script:Runspace)   { $script:Runspace.Close(); $script:Runspace.Dispose() } } catch {}
    $script:PowerShell = $null
    $script:Runspace   = $null
}

# --- XAML UI ---
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:shell="clr-namespace:System.Windows.Shell;assembly=PresentationFramework"
        Title="MKVMerge Template Processor" Height="650" Width="700"
        WindowStartupLocation="CenterScreen" AllowsTransparency="True" WindowStyle="None"
        Background="Transparent" Name="MainWindow" ResizeMode="CanResize">
    <shell:WindowChrome.WindowChrome>
        <shell:WindowChrome ResizeBorderThickness="8" CaptionHeight="30" CornerRadius="0" GlassFrameThickness="0" UseAeroCaptionButtons="False"/>
    </shell:WindowChrome.WindowChrome>
    <Border BorderBrush="#FF007ACC" BorderThickness="1" Background="#FF2D2D30">
        <Grid>
            <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
            <Border Grid.Row="0" Background="#FF252526" Height="30">
                <Grid>
                    <TextBlock Text="MKVMerge Template Processor" VerticalAlignment="Center" Margin="10,0,0,0" Foreground="White" FontWeight="SemiBold"/>
                    <Button Name="CloseButton" HorizontalAlignment="Right" Content="✕" Width="40" Height="30" shell:WindowChrome.IsHitTestVisibleInChrome="True">
                        <Button.Style>
                            <Style TargetType="Button">
                                <Setter Property="Background" Value="Transparent"/><Setter Property="Foreground" Value="White"/><Setter Property="BorderThickness" Value="0"/>
                                <Style.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#FFE81123"/></Trigger></Style.Triggers>
                            </Style>
                        </Button.Style>
                    </Button>
                </Grid>
            </Border>
            <Grid Grid.Row="1" Margin="15">
                <Grid.Resources>
                    <Style TargetType="Label"><Setter Property="Foreground" Value="#FFBBBBBB"/><Setter Property="Margin" Value="0,5,0,0"/></Style>
                    <Style TargetType="TextBox">
                        <Setter Property="Background" Value="#FF3E3E42"/><Setter Property="Foreground" Value="White"/><Setter Property="BorderBrush" Value="#FF007ACC"/><Setter Property="Padding" Value="5"/><Setter Property="VerticalContentAlignment" Value="Center"/>
                    </Style>
                    <Style x:Key="BrowseBtn" TargetType="Button">
                        <Setter Property="Background" Value="#FF3E3E42"/><Setter Property="Foreground" Value="White"/><Setter Property="BorderBrush" Value="#FF007ACC"/><Setter Property="Padding" Value="10,2"/><Setter Property="Margin" Value="5,0,0,0"/>
                    </Style>
                    <Style x:Key="ActionBtn" TargetType="Button">
                        <Setter Property="Foreground" Value="White"/><Setter Property="FontWeight" Value="Bold"/>
                        <Setter Property="Template">
                            <Setter.Value>
                                <ControlTemplate TargetType="Button">
                                    <Border Name="ActionBorder" Background="{TemplateBinding Background}" CornerRadius="3">
                                        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                    </Border>
                                    <ControlTemplate.Triggers>
                                        <Trigger Property="IsEnabled" Value="False">
                                            <Setter TargetName="ActionBorder" Property="Background" Value="#FF555555"/><Setter Property="Foreground" Value="#FFAAAAAA"/>
                                        </Trigger>
                                    </ControlTemplate.Triggers>
                                </ControlTemplate>
                            </Setter.Value>
                        </Setter>
                    </Style>
                </Grid.Resources>
                <StackPanel>
                    <Label Content="Input 1 (Main Files):"/>
                    <Grid Height="32">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                        <TextBox Name="TxtInput1" AllowDrop="True"/>
                        <Button Name="BtnFile1" Grid.Column="1" Content="Files..." Style="{StaticResource BrowseBtn}"/>
                        <Button Name="BtnDir1" Grid.Column="2" Content="Folder..." Style="{StaticResource BrowseBtn}"/>
                    </Grid>
                    <Label Content="Input 2 (Secondary Files - Optional):" Margin="0,15,0,0"/>
                    <Grid Height="32">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                        <TextBox Name="TxtInput2" AllowDrop="True"/>
                        <Button Name="BtnFile2" Grid.Column="1" Content="Files..." Style="{StaticResource BrowseBtn}"/>
                        <Button Name="BtnDir2" Grid.Column="2" Content="Folder..." Style="{StaticResource BrowseBtn}"/>
                    </Grid>
                    <Label Content="Output Directory:" Margin="0,15,0,0"/>
                    <Grid Height="32">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                        <TextBox Name="TxtOutput"/>
                        <Button Name="BtnOutputDir" Grid.Column="1" Content="Browse..." Style="{StaticResource BrowseBtn}"/>
                    </Grid>
                    <Label Content="MKVMerge Command Template:" Margin="0,15,0,0"/>
                    <TextBox Name="TxtTemplate" Height="100" AcceptsReturn="True" TextWrapping="Wrap" VerticalContentAlignment="Top" AllowDrop="True"/>
                    <Button Name="BtnProcess" Content="START BATCH PROCESSING" Height="50" Margin="0,20,0,0" Background="#FF007ACC" Style="{StaticResource ActionBtn}"/>

                    <!-- Progress Section (hidden until processing starts) -->
                    <StackPanel Name="ProgressPanel" Visibility="Collapsed" Margin="0,15,0,0">
                        <TextBlock Name="StatusLabel" Foreground="#FFDDDDDD" FontWeight="SemiBold" Margin="0,0,0,8"/>
                        <TextBlock Foreground="#FF999999" Text="Current File:" Margin="0,0,0,3" FontSize="11"/>
                        <ProgressBar Name="FileProgress" Height="20" Minimum="0" Maximum="100" Background="#FF3E3E42" Foreground="#FF007ACC" BorderBrush="#FF555555" BorderThickness="1"/>
                        <TextBlock Foreground="#FF999999" Text="Overall:" Margin="0,8,0,3" FontSize="11"/>
                        <ProgressBar Name="OverallProgress" Height="20" Minimum="0" Maximum="100" Background="#FF3E3E42" Foreground="#FF00AA44" BorderBrush="#FF555555" BorderThickness="1"/>
                        <Button Name="BtnCancel" Content="CANCEL" Height="38" Margin="0,12,0,0" Background="#FFE81123" Style="{StaticResource ActionBtn}"/>
                    </StackPanel>
                </StackPanel>
            </Grid>
        </Grid>
    </Border>
</Window>
"@

$script:Window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))

# --- Bind all named controls into a short-named hashtable ---
$C = @{}
@("CloseButton","TxtInput1","BtnFile1","BtnDir1","TxtInput2","BtnFile2","BtnDir2",
  "TxtOutput","BtnOutputDir","TxtTemplate","BtnProcess",
  "ProgressPanel","StatusLabel","FileProgress","OverallProgress","BtnCancel"
) | ForEach-Object { $C[$_] = $script:Window.FindName($_) }

# --- Drag/Drop Events ---
$OnDragOver = { param($s,$e) $e.Effects = [Windows.DragDropEffects]::Copy; $e.Handled = $true }

$C.TxtInput1.Add_PreviewDragOver($OnDragOver)
$C.TxtInput1.Add_Drop({ param($s,$e)
    if ($e.Data.GetDataPresent([Windows.DataFormats]::FileDrop)) {
        $f = $e.Data.GetData([Windows.DataFormats]::FileDrop)
        $s.Text = $f -join $script:PathDelimiter
        Update-DefaultOutput -FirstPath $f[0]
    }
})

$C.TxtInput2.Add_PreviewDragOver($OnDragOver)
$C.TxtInput2.Add_Drop({ param($s,$e)
    if ($e.Data.GetDataPresent([Windows.DataFormats]::FileDrop)) {
        $s.Text = ($e.Data.GetData([Windows.DataFormats]::FileDrop)) -join $script:PathDelimiter
    }
})

$C.TxtTemplate.Add_PreviewDragOver($OnDragOver)
$C.TxtTemplate.Add_Drop({ param($s,$e)
    if ($e.Data.GetDataPresent([Windows.DataFormats]::Text)) { $s.Text = $e.Data.GetData([Windows.DataFormats]::Text) }
})

# --- Browse & Close Events ---
$C.CloseButton.Add_Click({ Stop-BackgroundWork; $script:Window.Close() })
$C.BtnFile1.Add_Click({    Browse-Files  -TextBox $C.TxtInput1 -UpdateOutput })
$C.BtnDir1.Add_Click({     Browse-Folder -TextBox $C.TxtInput1 -UpdateOutput })
$C.BtnFile2.Add_Click({    Browse-Files  -TextBox $C.TxtInput2 })
$C.BtnDir2.Add_Click({     Browse-Folder -TextBox $C.TxtInput2 })
$C.BtnOutputDir.Add_Click({ Browse-Folder -TextBox $C.TxtOutput })

# --- Synchronized state for cross-thread communication ---
$Global:Sync = [hashtable]::Synchronized(@{
    Cancel      = $false
    CurrentProc = $null
})

# --- Cancel Button ---
$C.BtnCancel.Add_Click({
    $Global:Sync.Cancel = $true
    try { $p = $Global:Sync.CurrentProc; if ($p -and -not $p.HasExited) { $p.Kill() } } catch {}
})

# --- Processing Engine ---
$C.BtnProcess.Add_Click({
    $list1  = @(Get-SelectedPaths $C.TxtInput1.Text)
    $list2  = @(Get-SelectedPaths $C.TxtInput2.Text)
    $tpl    = $C.TxtTemplate.Text
    $outDir = $C.TxtOutput.Text

    # ---- Validation ----
    if ($list1.Count -eq 0)               { Show-MessageBox -Type "Error" -Message "Input 1 is empty!"; return }
    if ([string]::IsNullOrWhiteSpace($tpl)) { Show-MessageBox -Type "Error" -Message "Template is empty!"; return }

    $inputRegex = '\^"\^\(\^" .*? \^"\^\)\^"'
    $SlotMatches = [regex]::Matches($tpl, $inputRegex)

    if ($SlotMatches.Count -eq 1 -and $list2.Count -gt 0) {
        if ((Show-MessageBox -Type "Question" -Message "Template has 1 slot, but List 2 has files. Ignore List 2?") -ne "Yes") { return }
    }
    elseif ($SlotMatches.Count -ge 2 -and $list1.Count -ne $list2.Count) {
        Show-MessageBox -Type "Error" -Message "File counts do not match!"; return
    }

    # ---- Pre-build all commands on the UI thread ----
    $jobs = [System.Collections.ArrayList]::new()
    for ($i = 0; $i -lt $list1.Count; $i++) {
        $f1       = $list1[$i]
        $outName  = [System.IO.Path]::GetFileNameWithoutExtension($f1) + ".mkv"
        $finalOut = Join-Path $outDir $outName

        $cmd = $tpl
        $cmd = [regex]::Replace($cmd, '--output \^".*?\^"', "--output ^`"$finalOut^`"")

        $iterMatches = [regex]::Matches($cmd, $inputRegex)
        if ($iterMatches.Count -ge 1) {
            $cmd = $cmd.Replace($iterMatches[0].Value, "^`"^(^`" ^`"$f1^`" ^`"^)^`"")
        }
        if ($iterMatches.Count -ge 2 -and $i -lt $list2.Count) {
            $cmd = $cmd.Replace($iterMatches[1].Value, "^`"^(^`" ^`"$($list2[$i])^`" ^`"^)^`"")
        }

        $cleanCmd = $cmd -replace '\^', ''
        if ($cleanCmd -match '^"(.*?mkvmerge\.exe)"\s+(.*)$') {
            [void]$jobs.Add(@{ FileName = [System.IO.Path]::GetFileName($f1); Exe = $matches[1]; Args = $matches[2]; OutDir = $outDir })
        }
    }

    if ($jobs.Count -eq 0) { Show-MessageBox -Type "Error" -Message "No valid commands could be built from the template."; return }

    # ---- Switch UI to processing mode ----
    $C.BtnProcess.Content          = "PROCESSING..."
    $C.BtnProcess.IsEnabled        = $false
    $C.ProgressPanel.Visibility    = "Visible"
    $C.BtnCancel.Visibility        = "Visible"
    $C.FileProgress.Value          = 0
    $C.OverallProgress.Value       = 0
    $C.StatusLabel.Text            = "Starting..."
    $Global:Sync.Cancel            = $false
    $Global:Sync.CurrentProc       = $null

    # ---- Pass UI references to the sync hashtable ----
    $Global:Sync.Window          = $script:Window
    $Global:Sync.StatusLabel     = $C.StatusLabel
    $Global:Sync.FileProgress    = $C.FileProgress
    $Global:Sync.OverallProgress = $C.OverallProgress
    $Global:Sync.BtnProcess      = $C.BtnProcess
    $Global:Sync.BtnCancel       = $C.BtnCancel
    $Global:Sync.Jobs            = $jobs

    # ---- Clean up any previous runspace ----
    Stop-BackgroundWork

    # ---- Launch background runspace ----
    $script:Runspace = [runspacefactory]::CreateRunspace()
    $script:Runspace.ApartmentState = "STA"
    $script:Runspace.Open()
    $script:Runspace.SessionStateProxy.SetVariable("sync", $Global:Sync)

    $script:PowerShell = [powershell]::Create()
    $script:PowerShell.Runspace = $script:Runspace
    [void]$script:PowerShell.AddScript({
        $total  = $sync.Jobs.Count
        $errors = [System.Collections.ArrayList]::new()

        # Helper to invoke UI updates concisely
        $ui = { param($action) $sync.Window.Dispatcher.Invoke([Action]$action) }

        for ($i = 0; $i -lt $total; $i++) {
            if ($sync.Cancel) { break }

            $job = $sync.Jobs[$i]

            # Update status
            $sync.StatusText = "[$($i+1) / $total]  $($job.FileName)"
            $sync.OverallPct = [int]($i / $total * 100)
            & $ui { $sync.StatusLabel.Text = $sync.StatusText; $sync.FileProgress.Value = 0; $sync.OverallProgress.Value = $sync.OverallPct }

            # Ensure output directory exists
            if (-not (Test-Path $job.OutDir)) { New-Item -ItemType Directory -Path $job.OutDir -Force | Out-Null }

            # Start mkvmerge with --gui-mode for parseable progress
            $proc = New-Object System.Diagnostics.Process
            $proc.StartInfo.FileName               = $job.Exe
            $proc.StartInfo.Arguments              = "--gui-mode " + $job.Args
            $proc.StartInfo.UseShellExecute        = $false
            $proc.StartInfo.RedirectStandardOutput = $true
            $proc.StartInfo.CreateNoWindow         = $true
            $proc.Start() | Out-Null
            $sync.CurrentProc = $proc

            # Read stdout line-by-line for progress
            while (-not $proc.StandardOutput.EndOfStream) {
                if ($sync.Cancel) { try { $proc.Kill() } catch {}; break }
                $line = $proc.StandardOutput.ReadLine()

                if ($line -match '#GUI#progress\s+(\d+)') {
                    $sync.FilePct    = [int]$Matches[1]
                    $sync.OverallPct = [int](($i + $sync.FilePct / 100) / $total * 100)
                    & $ui { $sync.FileProgress.Value = $sync.FilePct; $sync.OverallProgress.Value = $sync.OverallPct }
                }
                elseif ($line -match '#GUI#(error|warning)') {
                    [void]$errors.Add("$($job.FileName): $line")
                }
            }

            if (-not $sync.Cancel) {
                $proc.WaitForExit()
                if ($proc.ExitCode -gt 1) { [void]$errors.Add("$($job.FileName): mkvmerge exited with code $($proc.ExitCode)") }
            }
            $proc.Dispose()
        }

        # Final UI update
        $sync.FinalStatus = if ($sync.Cancel) { "Cancelled after $i of $total file(s)." }
                            elseif ($errors.Count -gt 0) { "Done with $($errors.Count) warning(s)/error(s). Processed $total file(s)." }
                            else { "Complete! Processed $total file(s) successfully." }

        & $ui {
            $sync.StatusLabel.Text      = $sync.FinalStatus
            $sync.FileProgress.Value    = 100
            $sync.OverallProgress.Value = 100
            $sync.BtnProcess.Content    = "START BATCH PROCESSING"
            $sync.BtnProcess.IsEnabled  = $true
            $sync.BtnCancel.Visibility  = "Collapsed"
            [System.Media.SystemSounds]::Asterisk.Play()
        }
    })

    $script:PowerShell.BeginInvoke() | Out-Null
})

$script:Window.Add_Closed({ Stop-BackgroundWork })
$script:Window.ShowDialog() | Out-Null
