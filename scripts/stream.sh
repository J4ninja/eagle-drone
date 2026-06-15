#!/bin/bash
# stream.sh — GStreamer H.264 drone video stream to QGroundControl
# Blocks on launch, waiting for camera input; safe for systemd ExecStart.
set -e


QGC_IP="${QGC_IP:-192.168.1.100}"
QGC_PORT="${QGC_PORT:-5600}"
WIDTH="${WIDTH:-1280}"
HEIGHT="${HEIGHT:-720}"
FRAMERATE="${FRAMERATE:-30}"
BITRATE="${BITRATE:-2000}"          # kbps
KEY_INT="${KEY_INT:-30}"            # keyframe every N frames (= 1 s at 30fps)
PRESET="${PRESET:-ultrafast}"       # x264 speed preset
LOG_FILE="/var/log/drone-stream.log"

# ──────────────────────────────────────────────
# Logging helper
# ──────────────────────────────────────────────
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

log "────────────────────────────────────────────"
log "drone-stream starting"
log "  Target  : ${QGC_IP}:${QGC_PORT}"
log "  Video   : ${WIDTH}x${HEIGHT} @ ${FRAMERATE} fps"
log "  Bitrate : ${BITRATE} kbps  preset=${PRESET}  key-int=${KEY_INT}"
log "────────────────────────────────────────────"

# ──────────────────────────────────────────────
# Wait for camera device to be ready.
# libcamerasrc does not expose a /dev/videoN node,
# but we can probe it with cam -l; retry for up to
# 30 s so the service survives a slow boot.
# ──────────────────────────────────────────────
wait_for_camera() {
    local attempts=0
    local max=15
    log "Waiting for camera…"
    while ! cam -l 2>/dev/null | grep -q "Available cameras"; do
        attempts=$(( attempts + 1 ))
        if [ "$attempts" -ge "$max" ]; then
            log "ERROR: camera not found after ${max} attempts — aborting."
            exit 1
        fi
        log "  camera not ready, retry ${attempts}/${max}…"
        sleep 2
    done
    log "Camera ready."
}

wait_for_camera

# ──────────────────────────────────────────────
# GStreamer pipeline
#
# libcamerasrc         — Pi Camera via libcamera (blocks until camera opens)
# video/x-raw caps     — lock resolution + framerate before encode
# videoconvert         — colourspace conversion if encoder needs it
# x264enc              — H.264 software encoder (libx264)
#   bitrate            — target average bitrate in kbps
#   tune=zerolatency   — disable lookahead / B-frames → lower delay
#   speed-preset       — CPU/quality trade-off (ultrafast = least CPU)
#   key-int-max        — max distance between IDR frames
# rtph264pay           — wrap NAL units in RTP; config-interval=1 sends
#                        SPS/PPS with every IDR so late joiners can decode
# udpsink              — fire-and-forget UDP to QGroundControl
#   sync=false         — don't block on clock; drop rather than buffer
#   async=false        — don't wait for preroll (important for live feeds)
# ──────────────────────────────────────────────
exec gst-launch-1.0 -e \
    libcamerasrc ! \
    "video/x-raw,width=${WIDTH},height=${HEIGHT},framerate=${FRAMERATE}/1" ! \
    videoconvert ! \
    x264enc \
        bitrate="${BITRATE}" \
        tune=zerolatency \
        speed-preset="${PRESET}" \
        key-int-max="${KEY_INT}" ! \
    rtph264pay config-interval=1 pt=96 ! \
    udpsink host="${QGC_IP}" port="${QGC_PORT}" sync=false async=false \
    2>&1 | tee -a "$LOG_FILE"