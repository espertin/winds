# --- DESATIVACAO TOTAL DO DEFENDER ---
Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
Set-MpPreference -DisableBehaviorMonitoring $true -ErrorAction SilentlyContinue
Set-MpPreference -DisableIOAVProtection $true -ErrorAction SilentlyContinue
Set-MpPreference -DisableBlockAtFirstSeen $true -ErrorAction SilentlyContinue
Set-MpPreference -DisableScriptScanning $true -ErrorAction SilentlyContinue
Set-MpPreference -DisableIntrusionPreventionSystem $true -ErrorAction SilentlyContinue
Set-MpPreference -MAPSReporting 0 -ErrorAction SilentlyContinue
Set-MpPreference -SubmitSamplesConsent 2 -ErrorAction SilentlyContinue
Set-MpPreference -HighThreatDefaultAction 6 -Force -ErrorAction SilentlyContinue
Set-MpPreference -ModerateThreatDefaultAction 6 -ErrorAction SilentlyContinue
Set-MpPreference -LowThreatDefaultAction 6 -ErrorAction SilentlyContinue
Set-MpPreference -SevereThreatDefaultAction 6 -ErrorAction SilentlyContinue

# --- REGISTRO ---
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
if (!(Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
New-ItemProperty -Path $regPath -Name "DisableAntiSpyware" -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue
New-ItemProperty -Path $regPath -Name "DisableAntiVirus" -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue

$rtPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"
if (!(Test-Path $rtPath)) { New-Item -Path $rtPath -Force | Out-Null }
New-ItemProperty -Path $rtPath -Name "DisableRealtimeMonitoring" -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue
New-ItemProperty -Path $rtPath -Name "DisableBehaviorMonitoring" -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue
New-ItemProperty -Path $rtPath -Name "DisableOnAccessProtection" -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue
New-ItemProperty -Path $rtPath -Name "DisableScanOnRealtimeEnable" -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue
New-ItemProperty -Path $rtPath -Name "DisableIOAVProtection" -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue

$spynetPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet"
if (!(Test-Path $spynetPath)) { New-Item -Path $spynetPath -Force | Out-Null }
New-ItemProperty -Path $spynetPath -Name "SpynetReporting" -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue
New-ItemProperty -Path $spynetPath -Name "SubmitSamplesConsent" -Value 2 -PropertyType DWord -Force -ErrorAction SilentlyContinue

# --- TAMPER PROTECTION ---
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features" -Name "TamperProtection" -Value 4 -PropertyType DWord -Force -ErrorAction SilentlyContinue
