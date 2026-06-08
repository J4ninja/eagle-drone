#!/bin/bash
# benchmark.sh — H.264 encoding benchmark across x264 speed presets
#
# For each preset it runs a 10-second encode, then reports:
#   • Wall-clock time          (how long the encode took)
#   • Frames processed         (from gst-launch output)
#   • Effective FPS            (frames / wall time)
#   • CPU usage %              (sampled via /proc during encode)
#   • Output file size         (proxy for achieved bitrate)
#
# Usage:
#   chmod +x benchmark.sh
#   ./benchmark.sh
#   ./benchmark.sh --duration 20 --resolution 1920x1080
# ──────────────────────────────────────────────────────────────────────
set -e

# ── Defaults ──────────────────────────────────────────────────────────
DURATION=10          # seconds per preset test
WIDTH=1280
HEIGHT=720
FRAMERATE=30
BITRATE=2000         # kbps
OUTDIR="/tmp/gst-bench"
REPORT="${OUTDIR}/benchmark-report.txt"

# Parse optional args
while [[ $# -gt 0 ]]; do
    case $1 in
        --duration)  DURATION="$2";  shift 2 ;;
        --bitrate)   BITRATE="$2";   shift 2 ;;
        --resolution)
            WIDTH="${2%x*}"; HEIGHT="${2#*x}"; shift 2 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

mkdir -p "$OUTDIR"

PRESETS=("ultrafast" "superfast" "veryfast" "faster" "fast" "medium")

echo "══════════════════════════════════════════════════════════" | tee "$REPORT"
echo "  GStreamer x264enc Encoding Benchmark" | tee -a "$REPORT"
echo "  $(date)" | tee -a "$REPORT"
echo "  Resolution : ${WIDTH}x${HEIGHT}  Framerate: ${FRAMERATE}fps" | tee -a "$REPORT"
echo "  Bitrate    : ${BITRATE} kbps  Duration: ${DURATION}s" | tee -a "$REPORT"
echo "══════════════════════════════════════════════════════════" | tee -a "$REPORT"
printf "%-12s  %-10s  %-8s  %-10s  %-10s\n" \
    "PRESET" "WALL(s)" "FPS" "CPU%" "SIZE(MB)" | tee -a "$REPORT"
echo "──────────────────────────────────────────────────────────" | tee -a "$REPORT"

for PRESET in "${PRESETS[@]}"; do
    OUTFILE="${OUTDIR}/bench_${PRESET}.mp4"

    # Sample CPU in the background every 0.5 s while pipeline runs
    CPU_SAMPLES=()
    cpu_monitor() {
        while true; do
            cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | tr -d '%us,')
            CPU_SAMPLES+=("$cpu")
            sleep 0.5
        done
    }

    # Run encode to a file for duration seconds
    START_TS=$(date +%s%N)

    cpu_monitor &
    MON_PID=$!

    # videotestsrc used here as a stand-in for libcamerasrc so the
    # benchmark runs without a physical camera attached.
    # Replace 'videotestsrc' with 'libcamerasrc' on the real Pi.
    GST_OUT=$(gst-launch-1.0 -e \
        videotestsrc num-buffers=$(( FRAMERATE * DURATION )) ! \
        "video/x-raw,width=${WIDTH},height=${HEIGHT},framerate=${FRAMERATE}/1" ! \
        videoconvert ! \
        x264enc bitrate="${BITRATE}" tune=zerolatency \
            speed-preset="${PRESET}" key-int-max=30 ! \
        mp4mux ! \
        filesink location="${OUTFILE}" \
        2>&1 || true)

    END_TS=$(date +%s%N)
    kill "$MON_PID" 2>/dev/null || true
    wait "$MON_PID" 2>/dev/null || true

    # Wall time in seconds (floating point)
    WALL=$(echo "scale=2; ($END_TS - $START_TS) / 1000000000" | bc)

    # Frames: parse from gst-launch "Execution ended after" line or estimate
    FRAMES=$(echo "$GST_OUT" | grep -oP '\d+(?= frames)' | tail -1)
    FRAMES="${FRAMES:-$(( FRAMERATE * DURATION ))}"

    # FPS
    FPS=$(echo "scale=1; $FRAMES / $WALL" | bc)

    # Average CPU
    if [ ${#CPU_SAMPLES[@]} -gt 0 ]; then
        SUM=0
        for s in "${CPU_SAMPLES[@]}"; do SUM=$(echo "$SUM + $s" | bc); done
        AVG_CPU=$(echo "scale=1; $SUM / ${#CPU_SAMPLES[@]}" | bc)
    else
        AVG_CPU="N/A"
    fi

    # File size
    if [ -f "$OUTFILE" ]; then
        SIZE_BYTES=$(stat -c%s "$OUTFILE")
        SIZE_MB=$(echo "scale=2; $SIZE_BYTES / 1048576" | bc)
    else
        SIZE_MB="0.00"
    fi

    printf "%-12s  %-10s  %-8s  %-10s  %-10s\n" \
        "$PRESET" "${WALL}s" "${FPS}" "${AVG_CPU}%" "${SIZE_MB}" | tee -a "$REPORT"
done

echo "──────────────────────────────────────────────────────────" | tee -a "$REPORT"
echo "" | tee -a "$REPORT"
echo "Benchmark files saved to: ${OUTDIR}" | tee -a "$REPORT"
echo "Full report: ${REPORT}" | tee -a "$REPORT"
echo ""
echo "Recommendation:"
echo "  'veryfast' or 'faster' typically offers the best"
echo "  FPS/CPU trade-off at 720p30. Use 'ultrafast' only if CPU"
echo "  headroom is tight (other flight-controller processes running)."