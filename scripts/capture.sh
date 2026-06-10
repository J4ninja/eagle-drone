#!/bin/bash
# capture.sh -- Record a short H.264 segment from the Pi Camera to a local file.
# Usage:
#   ./capture.sh                        # 10s clip, 720p
#   ./capture.sh --duration 30
#   ./capture.sh --output /tmp/test.mp4
#   ./capture.sh --resolution 1920x1080 --bitrate 4000
set -e

DURATION=10
WIDTH=1280
HEIGHT=720
FRAMERATE=30
BITRATE=2000
PRESET="ultrafast"
OUTFILE="/home/robot/eagle-drone/capture_$(date '+%Y%m%d_%H%M%S').mp4"

while [[ $# -gt 0 ]]; do
    case $1 in
        --duration)   DURATION="$2";               shift 2 ;;
        --bitrate)    BITRATE="$2";                shift 2 ;;
        --preset)     PRESET="$2";                 shift 2 ;;
        --output)     OUTFILE="$2";                shift 2 ;;
        --resolution) WIDTH="${2%x*}"; HEIGHT="${2#*x}"; shift 2 ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

echo "Resolution : ${WIDTH}x${HEIGHT} @ ${FRAMERATE}fps"
echo "Duration   : ${DURATION}s"
echo "Bitrate    : ${BITRATE} kbps  preset=${PRESET}"
echo "Output     : ${OUTFILE}"
echo ""
echo "Recording...  (Ctrl-C to stop early and still get a valid file)"
echo ""

# timeout sends SIGINT after $DURATION seconds.
# -e tells gst-launch to treat it as EOS so mp4mux writes the moov atom
# and produces a valid, seekable file even when stopped mid-stream.
timeout --signal=INT "${DURATION}" \
gst-launch-1.0 -e \
    libcamerasrc ! \
    "video/x-raw,width=${WIDTH},height=${HEIGHT},framerate=${FRAMERATE}/1" ! \
    videoconvert ! \
    x264enc \
        bitrate="${BITRATE}" \
        tune=zerolatency \
        speed-preset="${PRESET}" \
        key-int-max=30 ! \
    h264parse ! \
    mp4mux ! \
    filesink location="${OUTFILE}" || true

echo ""
echo "Capture complete: ${OUTFILE}"
echo ""

if command -v ffprobe &>/dev/null; then
    echo "-- ffprobe report --"
    ffprobe -v quiet -show_streams -show_format "${OUTFILE}" 2>&1 \
        | grep -E "duration|bit_rate|codec_name|width|height|r_frame_rate" \
        | sed 's/^/  /'
else
    echo "(Install ffmpeg for quality stats: sudo apt install ffmpeg)"
fi

echo ""
echo "Copy to your machine:"
echo "  scp robot@<PI_IP>:${OUTFILE} ~/Desktop/"