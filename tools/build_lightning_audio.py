"""Convolve CC0 sparks with a deterministic synthetic station impulse response."""

from pathlib import Path
import subprocess

import numpy as np
from scipy import signal
from scipy.io import wavfile

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "assets/audio"
RATE = 44100


def write(name: str, audio: np.ndarray) -> None:
    """Normalize with headroom and save engine-ready PCM."""
    peak = np.max(np.abs(audio))
    assert peak > 0 and np.isfinite(audio).all()
    wavfile.write(AUDIO / name, RATE, (audio / peak * 0.82 * 32767).astype(np.int16))


def master(name: str, target: float) -> None:
    """Raise perceived level without letting sparse peaks consume the headroom."""
    destination = AUDIO / name
    intermediate = ROOT / "artifacts" / name
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-i",
            str(destination),
            "-af",
            f"acompressor=threshold=0.12:ratio=3:attack=3:release=160,"
            f"loudnorm=I={target}:TP=-1.5:LRA=7",
            "-ar",
            str(RATE),
            "-ac",
            "1",
            str(intermediate),
        ],
        check=True,
        capture_output=True,
    )
    rate, pcm = wavfile.read(intermediate)
    assert rate == RATE and np.max(np.abs(pcm.astype(np.int32))) < 32767
    wavfile.write(destination, rate, pcm)
    rms = np.sqrt(np.mean((pcm.astype(np.float64) / 32768) ** 2))
    print(f"{name}: {len(pcm) / rate:.2f}s, RMS {20 * np.log10(rms):.1f} dBFS")


def main() -> None:
    """Build reflections for an approximately 35 x 21 x 4.8 metre tiled hall."""
    decoded = ROOT / "artifacts/electric-decoded.wav"
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-i",
            str(AUDIO / "huge_arcs_source.mp3"),
            "-ss",
            "27",
            "-t",
            "53",
            "-ar",
            str(RATE),
            "-ac",
            "1",
            str(decoded),
        ],
        check=True,
        capture_output=True,
    )
    rate, pcm = wavfile.read(decoded)
    assert rate == RATE
    source = pcm.astype(np.float64) / 32768
    assert len(source) == RATE * 53, "Requested 0:27-1:20 excerpt is incomplete"
    # Remove subsonic rumble without losing the large, low electrical body.
    source = signal.sosfilt(
        signal.butter(2, 55, "highpass", fs=RATE, output="sos"), source
    )
    rng = np.random.default_rng(70213)
    t = np.arange(RATE * 4) / RATE
    # Synthetic diffuse decay: RT60 = 2.8 seconds, with softened high frequencies.
    tail = signal.sosfilt(
        signal.butter(2, 4200, fs=RATE, output="sos"), rng.normal(size=t.size)
    )
    impulse = tail * np.exp(-6.9078 * t / 2.8) * 0.018
    impulse[: int(0.018 * RATE)] = 0
    impulse[0] = 1
    for distance, gain in [(9.6, 0.48), (21, 0.37), (35, 0.32), (42, 0.21), (70, 0.14)]:
        impulse[round(distance / 343 * RATE)] += gain
    write("lightning_station_ir.wav", impulse)
    # A tiled source is convolved before extracting a loop: its tail wraps naturally.
    duration = len(source)
    repeated = np.tile(source, 3)
    wet = signal.fftconvolve(repeated, impulse)
    write("lightning_arc.wav", wet[duration : duration * 2])
    master("lightning_arc.wav", -13)
    impact_time = np.arange(RATE * 2) / RATE
    crack = source[np.argmax(np.abs(source)) :][: RATE // 2]
    impact = rng.normal(size=impact_time.size) * np.exp(-impact_time * 13) * 0.18
    impact += (
        np.sin(2 * np.pi * (65 * impact_time - 9 * impact_time**2))
        * np.exp(-impact_time * 3)
        * 0.4
    )
    impact[: len(crack)] += crack
    write("lightning_impact.wav", signal.fftconvolve(impact, impulse))
    master("lightning_impact.wav", -12)


if __name__ == "__main__":
    main()
