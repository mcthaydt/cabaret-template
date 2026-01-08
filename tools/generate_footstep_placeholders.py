#!/usr/bin/env python3
"""
Generate placeholder footstep sound effects for Phase 5 (Footstep System).

Creates 24 WAV files (6 surfaces × 4 variations):
- Default: 200Hz, 80ms
- Grass: 250Hz, 80ms
- Stone: 180Hz, 80ms
- Wood: 300Hz, 80ms
- Metal: 400Hz, 80ms
- Water: 150Hz, 100ms

Each surface has 4 variations to prevent repetitive feel.
"""

import numpy as np
from scipy.io import wavfile
import os

# Output directory
OUTPUT_DIR = "resources/audio/footsteps"

# Surface configurations: (name, frequency, duration_ms)
SURFACE_CONFIGS = [
	("default", 200, 80),
	("grass", 250, 80),
	("stone", 180, 80),
	("wood", 300, 80),
	("metal", 400, 80),
	("water", 150, 100),
]

# Audio parameters
SAMPLE_RATE = 44100  # 44.1kHz
AMPLITUDE = 0.3  # 30% volume to avoid clipping


def generate_tone(frequency: float, duration_ms: int, variation: int) -> np.ndarray:
	"""Generate a sine wave tone with slight pitch variation."""
	duration_sec = duration_ms / 1000.0
	num_samples = int(SAMPLE_RATE * duration_sec)

	# Add slight pitch variation per variation (±2% for variations 2-4)
	pitch_variations = [1.0, 0.98, 1.02, 0.99]
	frequency_adjusted = frequency * pitch_variations[variation]

	# Generate time array
	t = np.linspace(0, duration_sec, num_samples, endpoint=False)

	# Generate sine wave
	tone = AMPLITUDE * np.sin(2 * np.pi * frequency_adjusted * t)

	# Apply fade-in and fade-out envelope to reduce clicks
	fade_samples = int(0.005 * SAMPLE_RATE)  # 5ms fade
	fade_in = np.linspace(0, 1, fade_samples)
	fade_out = np.linspace(1, 0, fade_samples)

	tone[:fade_samples] *= fade_in
	tone[-fade_samples:] *= fade_out

	# Convert to int16 (WAV format)
	tone_int16 = np.int16(tone * 32767)

	return tone_int16


def main():
	"""Generate all placeholder footstep sounds."""
	# Ensure output directory exists
	os.makedirs(OUTPUT_DIR, exist_ok=True)

	total_files = len(SURFACE_CONFIGS) * 4
	print(f"Generating {total_files} placeholder footstep sounds...")

	for surface_name, frequency, duration_ms in SURFACE_CONFIGS:
		for variation in range(4):
			variation_num = variation + 1
			filename = f"placeholder_{surface_name}_{variation_num:02d}.wav"
			filepath = os.path.join(OUTPUT_DIR, filename)

			# Generate tone
			audio_data = generate_tone(frequency, duration_ms, variation)

			# Write WAV file
			wavfile.write(filepath, SAMPLE_RATE, audio_data)

			print(f"✓ {filename:40s} {frequency:4d}Hz × {duration_ms:3d}ms")

	print(f"\n✅ Successfully generated {total_files} footstep placeholder files in {OUTPUT_DIR}/")
	print("\n📝 Next step: Import files in Godot editor to generate .import files")


if __name__ == "__main__":
	main()
