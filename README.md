# EAGLE

ELDP Aerial General Purpose Lightweight Explorer Drone.

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

## Service

The systemd unit in [service/gstreamer-qgc.service](service/gstreamer-qgc.service) starts the GStreamer pipeline used to stream video from the Pi to QGroundControl.

## Setup

Run the scripts/setup.sh to install the systemd service and start script.

```bash
sudo scripts/setup.sh
```

