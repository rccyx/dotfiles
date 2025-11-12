#!/usr/bin/env bash
# Idempotent audio auto-switcher for PipeWire/PulseAudio

SINK="alsa_output.pci-0000_00_1f.3.analog-stereo"

# Detect if headphones are marked "available: yes"
if pactl list cards | grep -A20 "$SINK" | grep -q "analog-output-headphones.*available: yes"; then
  echo "Switching to headphones..."
  pactl set-sink-port "$SINK" analog-output-headphones
else
  echo "Switching to speakers..."
  pactl set-sink-port "$SINK" analog-output-speaker
fi

