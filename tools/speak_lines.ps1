param(
    [Parameter(Mandatory = $true)][string]$OutDir,
    [Parameter(Mandatory = $true)][string]$ListPath
)
$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
try {
    Add-Type -AssemblyName System.Speech
    $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
    $synth.SelectVoice("Microsoft Huihui Desktop")
    $synth.Rate = -2
    $synth.Volume = 100
    Get-Content -Encoding UTF8 $ListPath | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { return }
        $bar = $line.IndexOf("|")
        if ($bar -lt 1) { return }
        $id = $line.Substring(0, $bar)
        $text = $line.Substring($bar + 1)
        $out = Join-Path $OutDir ($id + ".wav")
        $synth.SetOutputToWaveFile($out)
        $synth.Speak($text)
        $synth.SetOutputToNull()
    }
    $synth.Dispose()
    $err = Join-Path $OutDir "error.txt"
    if (Test-Path $err) { Remove-Item $err -Force }
    exit 0
}
catch {
    Set-Content -Encoding UTF8 (Join-Path $OutDir "error.txt") $_.Exception.Message
    exit 0
}
