Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# --- Configuration & Helpers ---
$Global:PathDelimiter = "|||" 

function Show-MessageBox {
    param ([string]$Message, [string]$Title = "MKVMerge Batcher", [string]$Type = "Info")
    $image = switch ($Type) { "Error" { [System.Windows.MessageBoxImage]::Error } "Warning" { [System.Windows.MessageBoxImage]::Warning } "Question" { [System.Windows.MessageBoxImage]::Question } default { [System.Windows.MessageBoxImage]::Information } }
    $buttons = if ($Type -eq "Question") { [System.Windows.MessageBoxButton]::YesNo } else { [System.Windows.MessageBoxButton]::OK }
    return [System.Windows.MessageBox]::Show($Global:Window, $Message, $Title, $buttons, $image)
}

function Get-SelectedPaths {
    param ($InputString)
    if ([string]::IsNullOrWhiteSpace($InputString)) { return @() }
    
    # Check for multiple paths joined by delimiter
    if ($InputString -like "*$($Global:PathDelimiter)*") {
        return @($InputString -split [regex]::Escape($Global:PathDelimiter) | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
    }
    
    # Check if input is a directory
    if (Test-Path $InputString -PathType Container) {
        return @(Get-ChildItem -LiteralPath $InputString | Where-Object { ! $_.PSIsContainer } | Select-Object -ExpandProperty FullName)
    }
    
    # Single file path - wrapped in @() to prevent PowerShell from unwrapping it into a string later
    return @($InputString)
}

function Update-DefaultOutput {
    param($FirstPath)
    if ([string]::IsNullOrWhiteSpace($Controls.TxtOutput.Text) -and ![string]::IsNullOrWhiteSpace($FirstPath)) {
        try {
            $parent = if (Test-Path $FirstPath -PathType Container) { $FirstPath } else { Split-Path $FirstPath -Parent }
            $Controls.TxtOutput.Text = Join-Path $parent "_output"
        } catch {}
    }
}

# --- XAML UI ---
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:shell="clr-namespace:System.Windows.Shell;assembly=PresentationFramework"
        Title="MKVMerge Template Processor" Height="500" Width="700"
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
                    <Button Name="BtnProcess" Content="START BATCH PROCESSING" Height="50" Margin="0,20,0,0" FontWeight="Bold" Background="#FF007ACC" Foreground="White">
                        <Button.Style>
                            <Style TargetType="Button">
                                <Setter Property="Template">
                                    <Setter.Value>
                                        <ControlTemplate TargetType="Button">
                                            <Border Name="MainBorder" Background="{TemplateBinding Background}" CornerRadius="3">
                                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                            </Border>
                                            <ControlTemplate.Triggers>
                                                <Trigger Property="IsEnabled" Value="False">
                                                    <Setter TargetName="MainBorder" Property="Background" Value="#FF777777"/><Setter Property="Foreground" Value="White"/>
                                                </Trigger>
                                            </ControlTemplate.Triggers>
                                        </ControlTemplate>
                                    </Setter.Value>
                                </Setter>
                                <Style.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#FF005A9E"/></Trigger></Style.Triggers>
                            </Style>
                        </Button.Style>
                    </Button>
                </StackPanel>
            </Grid>
        </Grid>
    </Border>
</Window>
"@

$Global:Window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$Controls = @{}
"CloseButton","TxtInput1","BtnFile1","BtnDir1","TxtInput2","BtnFile2","BtnDir2","TxtOutput","BtnOutputDir","TxtTemplate","BtnProcess" | ForEach-Object { $Controls[$_] = $Global:Window.FindName($_) }

# --- Events ---
$OnDragOver = { param($s,$e) $e.Effects = [Windows.DragDropEffects]::Copy; $e.Handled = $true }
$Controls.TxtInput1.Add_Drop({ param($s,$e) if ($e.Data.GetDataPresent([Windows.DataFormats]::FileDrop)) { $f = $e.Data.GetData([Windows.DataFormats]::FileDrop); $s.Text = $f -join $Global:PathDelimiter; Update-DefaultOutput -FirstPath $f[0] } })
$Controls.TxtInput1.Add_PreviewDragOver($OnDragOver)
$Controls.TxtInput2.Add_Drop({ param($s,$e) if ($e.Data.GetDataPresent([Windows.DataFormats]::FileDrop)) { $f = $e.Data.GetData([Windows.DataFormats]::FileDrop); $s.Text = $f -join $Global:PathDelimiter } })
$Controls.TxtInput2.Add_PreviewDragOver($OnDragOver)
$Controls.TxtTemplate.Add_Drop({ param($s,$e) if ($e.Data.GetDataPresent([Windows.DataFormats]::Text)) { $s.Text = $e.Data.GetData([Windows.DataFormats]::Text) } })
$Controls.TxtTemplate.Add_PreviewDragOver($OnDragOver)
$Controls.CloseButton.Add_Click({ $Global:Window.Close() })
$Controls.BtnFile1.Add_Click({ $d = New-Object System.Windows.Forms.OpenFileDialog; $d.Multiselect = $true; if ($d.ShowDialog() -eq "OK") { $Controls.TxtInput1.Text = $d.FileNames -join $Global:PathDelimiter; Update-DefaultOutput -FirstPath $d.FileNames[0] } })
$Controls.BtnDir1.Add_Click({ $d = New-Object System.Windows.Forms.FolderBrowserDialog; if ($d.ShowDialog() -eq "OK") { $Controls.TxtInput1.Text = $d.SelectedPath; Update-DefaultOutput -FirstPath $d.SelectedPath } })
$Controls.BtnFile2.Add_Click({ $d = New-Object System.Windows.Forms.OpenFileDialog; $d.Multiselect = $true; if ($d.ShowDialog() -eq "OK") { $Controls.TxtInput2.Text = $d.FileNames -join $Global:PathDelimiter } })
$Controls.BtnDir2.Add_Click({ $d = New-Object System.Windows.Forms.FolderBrowserDialog; if ($d.ShowDialog() -eq "OK") { $Controls.TxtInput2.Text = $d.SelectedPath } })
$Controls.BtnOutputDir.Add_Click({ $d = New-Object System.Windows.Forms.FolderBrowserDialog; if ($d.ShowDialog() -eq "OK") { $Controls.TxtOutput.Text = $d.SelectedPath } })

# --- Processing Engine ---
$Controls.BtnProcess.Add_Click({
    # We force these into arrays using @() to stop PowerShell from "unwrapping" single files into strings
    $list1 = @(Get-SelectedPaths $Controls.TxtInput1.Text)
    $list2 = @(Get-SelectedPaths $Controls.TxtInput2.Text)
    $tpl = $Controls.TxtTemplate.Text
    $outDir = $Controls.TxtOutput.Text

    if ($list1.Count -eq 0) { Show-MessageBox -Type "Error" -Message "Input 1 is empty!"; return }
    if ([string]::IsNullOrWhiteSpace($tpl)) { Show-MessageBox -Type "Error" -Message "Template is empty!"; return }

    $inputRegex = '\^"\^\(\^" .*? \^"\^\)\^"'
    $SlotMatches = [regex]::Matches($tpl, $inputRegex)
    
    if ($SlotMatches.Count -eq 1 -and $list2.Count -gt 0) {
        if ((Show-MessageBox -Type "Question" -Message "Template has 1 slot, but List 2 has files. Ignore List 2?") -ne "Yes") { return }
    }
    elseif ($SlotMatches.Count -ge 2 -and $list1.Count -ne $list2.Count) {
        Show-MessageBox -Type "Error" -Message "File counts do not match!"; return
    }

    $Controls.BtnProcess.Content = "PROCESSING FILES..."
    $Controls.BtnProcess.IsEnabled = $false
    $Global:Window.UpdateLayout()
    [System.Windows.Forms.Application]::DoEvents()

    try {
        for ($i = 0; $i -lt $list1.Count; $i++) {
            $f1 = $list1[$i]
            $outName = [System.IO.Path]::GetFileNameWithoutExtension($f1) + ".mkv"
            $finalOut = Join-Path $outDir $outName
            if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force }

            $cmd = $tpl
            $cmd = [regex]::Replace($cmd, '--output \^".*?\^"', "--output ^`"$finalOut^`"")
            
            $iterMatches = [regex]::Matches($cmd, $inputRegex)
            if ($iterMatches.Count -ge 1) { 
                $cmd = $cmd.Replace($iterMatches[0].Value, ("^`"^(^`" ^`"$f1^`" ^`"^)^`"" )) 
            }
            if ($iterMatches.Count -ge 2 -and $i -lt $list2.Count) { 
                $cmd = $cmd.Replace($iterMatches[1].Value, ("^`"^(^`" ^`"$($list2[$i])^`" ^`"^)^`"" )) 
            }

            $cleanCmd = $cmd -replace '\^', ''
            Write-Host "`n>>> Processing [$($i+1)/$($list1.Count)]: $([System.IO.Path]::GetFileName($f1))"
            
            # The -match operator populates the automatic $matches variable
            if ($cleanCmd -match '^"(.*?mkvmerge\.exe)"\s+(.*)$') {
                $exe = $matches[1]
                $args = $matches[2]
                Start-Process -FilePath $exe -ArgumentList $args -Wait -NoNewWindow
            } else {
                Write-Host "Failed to parse command for: $f1"
            }
        }
    } finally {
        [System.Media.SystemSounds]::Asterisk.Play()
        $Controls.BtnProcess.Content = "START BATCH PROCESSING"
        $Controls.BtnProcess.IsEnabled = $true
    }
})

$Global:Window.ShowDialog() | Out-Null
