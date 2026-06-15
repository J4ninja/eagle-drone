#!/bin/bash
set -e

ENV_FILE="/etc/eagle-stream.env"
if [ -f "$ENV_FILE" ]; then
    # shellcheck source=/dev/null
    source "$ENV_FILE"
fi

QGC_IP="192.168.1.100"

# libcamerasrc:
#   Gets frames from the Pi Camera using libcamera.
#
# video/x-raw:
#   Requests 1280x720 resolution at 30 FPS.
#
# videoconvert:
#   Converts image formats if required by the encoder.
#
# x264enc:
#   Compresses raw video into H.264.
#   bitrate=2000 -> ~2 Mbps stream.
#   tune=zerolatency -> lower delay.
#   speed-preset=ultrafast -> use less CPU.
#
# rtph264pay:
#   Packages H.264 into RTP packets for network transport.
#
# udpsink:
#   Sends packets to QGroundControl.
exec gst-launch-1.0 -e \
    libcamerasrc ! \
    video/x-raw,width=1280,height=720,framerate=30/1 ! \
    videoconvert ! \
    x264enc bitrate=2000 tune=zerolatency speed-preset=ultrafast key-int-max=30 ! \
    rtph264pay config-interval=1 pt=96 ! \
    udpsink host=${QGC_IP} port=5600 sync=false async=false