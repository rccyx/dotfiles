vocaster-default() {
  local sink_name vocaster_id default_id

  echo "🔎 Scanning sinks..."
  pactl list short sinks | awk '{print NR") "$2}' | sed 's/^/   /'

  # Find Vocaster sink (matches "Vocaster_One")
  sink_name=$(pactl list short sinks | awk '/Vocaster_One/ {print $2; exit}')
  if [[ -z "$sink_name" ]]; then
    echo "❌ Vocaster One sink not found. Aborting."
    return 1
  fi
  echo "✔ Found Vocaster sink: $sink_name"

  # Get current default sink
  default_id=$(pactl info | awk -F': ' '/Default Sink/ {print $2}')
  echo "ℹ️  Current default sink: $default_id"

  # If already default, exit quietly
  if [[ "$default_id" == "$sink_name" ]]; then
    echo "✔ Vocaster One is already the default sink. No changes made."
    return 0
  fi

  echo "⚡ Switching default sink to: $sink_name"
  pactl set-default-sink "$sink_name"

  # Move all active streams
  local moved=0
  for id in $(pactl list short sink-inputs | awk '{print $1}'); do
    echo "➡️  Moving stream $id → $sink_name"
    pactl move-sink-input "$id" "$sink_name"
    moved=$((moved+1))
  done

  echo "✔ Vocaster One set as default sink."
  echo "✔ Streams moved: $moved"
}

