param(
    [Parameter(Mandatory = $true)][string]$OutDir,
    [Parameter(Mandatory = $true)][string]$ListPath
)
$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Add-Type -AssemblyName System.Speech
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$synth.SelectVoice("Microsoft Huihui Desktop")
$synth.Volume = 100
Get-Content -Encoding UTF8 $ListPath | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq "" -or $line.StartsWith("#")) { return }
    $parts = $line.Split("|")
    if ($parts.Length -lt 4) { return }
    $id = $parts[0]
    $rate = $parts[1]
    $pitch = $parts[2]
    $text = $parts[3]
    $safe = [System.Security.SecurityElement]::Escape($text)
    $xml = "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='zh-CN'><prosody rate='$rate' pitch='$pitch'>$safe</prosody></speak>"
    $out = Join-Path $OutDir ($id + ".wav")
    $synth.SetOutputToWaveFile($out)
    $synth.SpeakSsml($xml)
    $synth.SetOutputToNull()
}
$synth.Dispose()
