#!/usr/bin/env python3
"""
Generate placeholder ambient audio files for testing.
Creates 10-second loops with distinct tones for exterior vs interior ambience.
"""

import numpy as np
import wave
import struct
import os

# Audio parameters
SAMPLE_RATE = 44100
DURATION = 10.0  # 10 seconds
NUM_SAMPLES = int(SAMPLE_RATE * DURATION)

def generate_ambient_tone(base_freq, variation_freq, variation_rate, amplitude=0.15):
    """
    Generate ambient tone with slow frequency variation for organic feel.

    Args:
        base_freq: Base frequency in Hz
        variation_freq: Amount of frequency variation in Hz
        variation_rate: Rate of variation in Hz (how fast it oscillates)
        amplitude: Volume (0.0 to 1.0)
    """
    t = np.linspace(0, DURATION, NUM_SAMPLES, False)

    # Create frequency modulation for organic variation
    freq_modulation = base_freq + variation_freq * np.sin(2 * np.pi * variation_rate * t)

    # Generate the tone with frequency modulation
    phase = np.cumsum(2 * np.pi * freq_modulation / SAMPLE_RATE)
    wave_data = amplitude * np.sin(phase)

    # Add subtle harmonics for richer sound
    wave_data += 0.5 * amplitude * np.sin(2 * phase)  # 1st harmonic
    wave_data += 0.25 * amplitude * np.sin(3 * phase)  # 2nd harmonic

    # Normalize to prevent clipping
    wave_data = wave_data / np.max(np.abs(wave_data)) * amplitude

    # Apply fade in/out at edges for seamless looping
    fade_samples = int(SAMPLE_RATE * 0.01)  # 10ms fade
    fade_in = np.linspace(0, 1, fade_samples)
    fade_out = np.linspace(1, 0, fade_samples)
    wave_data[:fade_samples] *= fade_in
    wave_data[-fade_samples:] *= fade_out

    return wave_data

def save_wav(filename, audio_data):
    """Save audio data as WAV file."""
    # Convert to 16-bit PCM
    audio_data_int = np.int16(audio_data * 32767)

    # Ensure directory exists
    os.makedirs(os.path.dirname(filename), exist_ok=True)

    # Write WAV file
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)  # Mono
        wav_file.setsampwidth(2)  # 16-bit
        wav_file.setframerate(SAMPLE_RATE)
        wav_file.writeframes(audio_data_int.tobytes())

    print(f"Generated: {filename}")

def main():
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    output_dir = os.path.join(project_root, "resources", "audio", "ambient")

    # Exterior ambient: Lower frequency, wider variation (outdoor wind-like)
    print("Generating exterior ambient (80Hz base, outdoor ambience)...")
    exterior_data = generate_ambient_tone(
        base_freq=80,
        variation_freq=15,
        variation_rate=0.3,
        amplitude=0.15
    )
    save_wav(os.path.join(output_dir, "placeholder_exterior.wav"), exterior_data)

    # Interior ambient: Higher frequency, tighter variation (room tone/HVAC-like)
    print("Generating interior ambient (120Hz base, room tone)...")
    interior_data = generate_ambient_tone(
        base_freq=120,
        variation_freq=8,
        variation_rate=0.5,
        amplitude=0.12
    )
    save_wav(os.path.join(output_dir, "placeholder_interior.wav"), interior_data)

    print("\nAmbient placeholders generated successfully!")
    print("Note: Import these as OGG in Godot for looping support.")
    print("  1. Copy WAV files to resources/audio/ambient/")
    print("  2. In Godot: Select each WAV → Import tab → Loop Mode: Forward → Reimport")

if __name__ == "__main__":
    main()
