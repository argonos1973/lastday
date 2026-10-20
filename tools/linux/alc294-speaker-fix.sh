#!/usr/bin/env bash
set -u

# ALC294 on the affected SOF laptops needs coefficient 0x1b bit 10 enabled
# after a cold power-off. Run as root via alc294-speaker-fix.service.
HDAV="${HDAV:-/usr/local/bin/hdav}"
AUDIO_USER="${AUDIO_USER:-sami}"
if [[ ! -x "$HDAV" ]]; then
	logger -t alc294-speaker-fix "missing executable: $HDAV"
	exit 1
fi

# Wake the real SOF/PipeWire speaker path. A direct hw:0,0 ALSA stream does
# not power this codec on this laptop and makes the vendor verbs silently no-op.
runtime_dir="/run/user/$(id -u "$AUDIO_USER")"
pulse_server="unix:${runtime_dir}/pulse/native"
if [[ ! -S "${runtime_dir}/pulse/native" ]]; then
	logger -t alc294-speaker-fix "PipeWire PulseAudio socket is not ready for $AUDIO_USER"
	exit 1
fi
pulse_sink="$(runuser -u "$AUDIO_USER" -- env XDG_RUNTIME_DIR="$runtime_dir" PULSE_SERVER="$pulse_server" pactl get-default-sink 2>/dev/null)" || exit 1
if [[ -z "$pulse_sink" ]]; then
	logger -t alc294-speaker-fix "no default PipeWire sink for $AUDIO_USER"
	exit 1
fi
runuser -u "$AUDIO_USER" -- env XDG_RUNTIME_DIR="$runtime_dir" PULSE_SERVER="$pulse_server" PULSE_SINK="$pulse_sink" \
	timeout 4s paplay --raw --format=s16le --rate=48000 --channels=2 /dev/zero >/dev/null 2>&1 &
playback_pid=$!
trap 'kill "$playback_pid" >/dev/null 2>&1 || true' EXIT
sleep 0.75

for attempt in 1 2 3 4 5; do
	if ! "$HDAV" 0x20 0x500 0x1b >/dev/null 2>&1 || \
		! "$HDAV" 0x20 0x400 0x4e4b >/dev/null 2>&1 || \
		! "$HDAV" 0x20 0x500 0x1b >/dev/null 2>&1; then
		logger -t alc294-speaker-fix "HDA verb write failed on attempt $attempt"
		sleep 1
		continue
	fi
	# GET_PROC_COEF reports 0 on this SOF firmware even when writes are issued;
	# record it for diagnostics but don't mark a successful verb sequence failed.
	readback=$("$HDAV" 0x20 0xf00 0 2>&1 || true)
	logger -t alc294-speaker-fix "coefficient write sequence completed on attempt $attempt; GET_PROC_COEF response: $readback"
	systemctl stop alc294-speaker-fix.timer >/dev/null 2>&1 || true
	exit 0
done

logger -t alc294-speaker-fix "could not issue coefficient 0x1b writes"
exit 1
