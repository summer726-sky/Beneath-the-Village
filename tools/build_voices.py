"""Build character voices into audio/voice.

Three Chinese men share Piper 超文, then each file is retuned:
player stays in the middle, 战友甲 drops and darkens, 战友乙 rises and brightens.
Three village women share Windows Huihui, then each file is retuned:
村民1 older and lower, 村民2 young and bright, 村民3 young and firmer.
Six Japanese soldiers share OpenJTalk NIT ATR503 M001, each at his own pitch and speed.
"""
from __future__ import annotations

import subprocess
import sys
import wave
from pathlib import Path

import numpy as np
from piper import PiperVoice
from piper.config import SynthesisConfig

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / "tools" / "_cache"
OUT = ROOT / "audio" / "voice"
MODEL = CACHE / "zh_CN-chaowen-medium.onnx"
JTALK = CACHE / "openjtalk" / "open_jtalk.exe"
VOICE = CACHE / "hts_voice_nitech_jp_atr503_m001-1.05" / "nitech_jp_atr503_m001.htsvoice"
DIC = CACHE / "open_jtalk_dic_shift_jis-1.11"


def _read(path: Path) -> tuple[int, np.ndarray]:
    with wave.open(str(path), "rb") as src:
        rate = src.getframerate()
        frames = src.readframes(src.getnframes())
    return rate, np.frombuffer(frames, dtype=np.int16).astype(np.float32)


def _write(path: Path, rate: int, samples: np.ndarray) -> None:
    with wave.open(str(path), "wb") as dst:
        dst.setnchannels(1)
        dst.setsampwidth(2)
        dst.setframerate(rate)
        dst.writeframes(np.clip(samples, -32767, 32767).astype(np.int16).tobytes())


def _lowpass(samples: np.ndarray, rate: int, cutoff: float) -> np.ndarray:
    coeff = float(np.exp(-2.0 * np.pi * cutoff / rate))
    out = np.empty_like(samples)
    acc = 0.0
    mix = 1.0 - coeff
    for i, sample in enumerate(samples):
        acc = mix * float(sample) + coeff * acc
        out[i] = acc
    return out


def color_wave(path: Path, brightness: float) -> None:
    if abs(brightness) < 0.05:
        return
    rate, samples = _read(path)
    if brightness < 0.0:
        cutoff = 1400.0 + (1.0 + brightness) * 2600.0
        samples = _lowpass(samples, rate, cutoff)
    else:
        base = _lowpass(samples, rate, 1300.0)
        samples = samples + (samples - base) * (0.85 * brightness)
    _write(path, rate, samples)


def normalize(path: Path, peak: float = 0.9) -> None:
    rate, samples = _read(path)
    loud = float(np.max(np.abs(samples))) if samples.size else 0.0
    if loud < 1.0:
        return
    _write(path, rate, samples * (peak * 32767.0) / loud)


def shift_pitch(path: Path, semitones: float) -> None:
    if abs(semitones) < 0.05:
        return
    rate, samples = _read(path)
    factor = 2 ** (semitones / 12.0)
    _write(path, max(1, int(round(rate * factor))), samples)


def finish(path: Path, semitones: float, brightness: float) -> None:
    color_wave(path, brightness)
    shift_pitch(path, semitones)
    normalize(path)


def speak_piper(
    voice: PiperVoice,
    text: str,
    path: Path,
    length_scale: float,
    semitones: float,
    brightness: float,
    noise: float,
    noise_w: float,
) -> None:
    with wave.open(str(path), "wb") as wav:
        voice.synthesize_wav(
            text,
            wav,
            syn_config=SynthesisConfig(
                length_scale=length_scale,
                noise_scale=noise,
                noise_w_scale=noise_w,
                volume=1.0,
            ),
        )
    finish(path, semitones, brightness)


def speak_japanese(text: str, path: Path, half_tone: float, speed: float) -> None:
    src = CACHE / "_ja_in.txt"
    src.write_bytes(text.encode("cp932") + b"\r\n")
    subprocess.run(
        [
            str(JTALK),
            "-m", str(VOICE),
            "-x", str(DIC),
            "-ow", str(path),
            "-fm", str(half_tone),
            "-r", str(speed),
            str(src),
        ],
        check=True,
    )
    normalize(path)


def speak_huihui(rows: list[tuple[str, str, str, str, float, float]]) -> None:
    listing = CACHE / "_huihui.txt"
    payload = "\n".join("|".join(row[:4]) for row in rows) + "\n"
    listing.write_bytes(b"\xef\xbb\xbf" + payload.encode("utf-8"))
    subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", str(ROOT / "tools" / "speak_cast.ps1"),
            "-OutDir", str(OUT),
            "-ListPath", str(listing),
        ],
        check=True,
    )
    for row in rows:
        finish(OUT / f"{row[0]}.wav", row[4], row[5])


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    male = PiperVoice.load(MODEL, download_dir=CACHE)
    player = [
        ("player_explore", "先把地道走熟。钟在院子的树下。", 1.08),
        ("player_warn", "有敌情！快隐蔽！", 0.86),
        ("player_hide", "往北房夹壁走，别出声！", 0.9),
        ("player_quiet", "小声点，别让敌军听见！", 0.92),
    ]
    for name, text, speed in player:
        speak_piper(male, text, OUT / f"{name}.wav", speed, 0.0, 0.0, 0.55, 0.55)
        print("piper", name)
    for name, text in (
        ("ally_jia_port", "守这个孔。"),
        ("ally_jia_barrier", "去关隔板。"),
        ("ally_jia_standby", "原地待命。"),
    ):
        speak_piper(male, text, OUT / f"{name}.wav", 1.06, -4.5, -0.85, 0.28, 0.32)
        print("piper", name)
    for name, text in (
        ("ally_yi_port", "守这个孔。"),
        ("ally_yi_barrier", "去关隔板。"),
        ("ally_yi_standby", "原地待命。"),
    ):
        speak_piper(male, text, OUT / f"{name}.wav", 0.76, 3.6, 0.9, 0.82, 0.95)
        print("piper", name)
    speak_huihui([
        ("villager_1_alarm", "76%", "-2%", "有敌情！快往北房夹壁躲！", -3.4, -0.75),
        ("villager_1_water", "78%", "-4%", "鬼子在灌水，快去关隔板！", -3.4, -0.75),
        ("villager_2_alarm", "118%", "+12%", "有敌情！快往北房夹壁躲！", 3.0, 0.85),
        ("villager_2_water", "116%", "+10%", "鬼子在灌水，快去关隔板！", 3.0, 0.85),
        ("villager_3_alarm", "104%", "-8%", "有敌情！快往北房夹壁躲！", -0.8, 0.15),
        ("villager_3_water", "102%", "-10%", "鬼子在灌水，快去关隔板！", -0.8, 0.15),
    ])
    print("huihui done")
    if "--no-ja" in sys.argv:
        return
    if not DIC.exists():
        raise SystemExit(f"missing dictionary: {DIC}")
    # Spawn order in main.gd: 0 分队长, 1/2/4/5 步枪手, 3 工兵.
    profiles = [
        (-4.2, 0.86),
        (3.4, 1.30),
        (0.8, 1.06),
        (-1.6, 0.98),
        (2.1, 1.16),
        (-2.6, 1.10),
    ]
    for index, (tone, speed) in enumerate(profiles):
        speak_japanese("撃て！", OUT / f"enemy_{index}_fire.wav", tone, speed)
        speak_japanese("穴を探せ！", OUT / f"enemy_{index}_hole.wav", tone, speed * 0.96)
        speak_japanese("前へ！", OUT / f"enemy_{index}_advance.wav", tone, speed)
        speak_japanese("井戸に水を入れろ！", OUT / f"enemy_{index}_pour.wav", tone, speed * 0.94)
        print("ja", index)
    print("ja orders", (OUT / "enemy_0_advance.wav").stat().st_size, (OUT / "enemy_3_pour.wav").stat().st_size)


if __name__ == "__main__":
    main()
