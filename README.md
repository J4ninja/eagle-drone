# EAGLE

ELDP Aerial General Purpose Lightweight Explorer Drone. The drone will use a Raspberry Pi + Raspberry Pi camera with to stream video feed to [QGroundControl](https://qgroundcontrol.com/) via [GStreamer](https://gstreamer.freedesktop.org/documentation/index.html?gi-language=c).

## Concept of Operations

EAGLE provides a live, low-latency video stream from a Raspberry Pi camera to QGroundControl during flight or bench testing. The Pi runs a GStreamer pipeline that encodes H.264 and sends it over UDP to the ground station. Operators start by imaging the Pi, configuring networking/SSH, installing dependencies, and enabling the streaming service. Once the service is enabled, the video feed is available on boot for QGroundControl to display.

```mermaid
flowchart LR
	Cam[Pi Camera] --> Lib[libcamera]
	Lib --> Gst[GStreamer H.264 Pipeline]
	Gst --> Udp[UDP Stream :5600]
	Udp --> QGC[QGroundControl]
	QGC --> Op[Operator View]
```

# Pi Setup

## Prerequisites

- A Raspberry Pi already imaged with Raspberry Pi OS and network access.
- Optional remote access via [Raspberry Pi Connect](https://www.raspberrypi.com/software/connect/) if you do not want to use local SSH.
## SSH
SSH once to the Raspberry Pi to establish the host.

```bash
ssh robot@eaglepi.local 
```

## Ansible
If you have ansible installed on a control-node (e.g. your laptop on the same network), you can run the ansible playbooks. You will need to input the SSH Password.

Install dependencies on the Pi using the inventory at [ansible/inventory/hosts.yml](ansible/inventory/hosts.yml) and the playbook in [ansible/playbooks/install-deps.yml](ansible/playbooks/install-deps.yml):

```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/install-deps.yml --ask-pass
```

Setup the Streaming service using the playbook in [ansible/playbooks/setup-service.yml](ansible/playbooks/setup-service.yml):

```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/setup-service.yml --ask-pass
```

# Testing the Camera
Clone this repository on the Pi.

## Pi camera test

Run the camera test script:

```bash
./scripts/test_camera.sh # Takes a still picture saved to test.jpg
```

Run a live camera feed:

```bash
./scripts/live_stream.sh # starts a live camera feed (requires GUI login)
```

# Service

The systemd unit in [service/gstreamer-qgc.service](service/gstreamer-qgc.service) starts the GStreamer pipeline used to stream video from the Pi to QGroundControl.

