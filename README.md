# SNSPD Agent

This repository provides a setup for deploying the SNSPD Agent using Docker. The agent controls a Quantum Opus SNSPD system through its QOELEC electronics module. It handles detector bias, cryostat temperatures, a coarse count rate and counts-versus-bias sweeps.

## Prerequisites

- Docker installed on your system.
- Access to the Docker image `ghcr.io/measurement-plane/snspd-agent:latest`.
- A running message broker (e.g., NATS) accessible at the specified `BROKER_URL`.
- For real hardware: the QOELEC module connected over USB. It shows up as a USB serial device (Microchip VID `04D8`, PID `EF24`), usually `/dev/ttyACM*`.
- No other process holding the QOELEC serial port. Stop the standalone `QuantumOpusServer.py` and `QuantumOpusLogger.py` scripts first.

## Quick Start

### 1. Clone the Repository
```bash
git clone <repo-url>
cd snspd-agent-ops
```

### 2. Find the QOELEC Device
Use the stable by-id path so the device name does not change across reboots or replugging:

```bash
ls -l /dev/serial/by-id/
```

### 3. Configure Environment Variables
All settings can be overridden from the shell before invoking `run.sh` (or edited directly in the script). Defaults:

```bash
BROKER_URL="nats://172.17.0.1:4222"   # Address of the message broker
ENDPOINT="/snspd/fury"                # Endpoint name for the agent
SNSPD_NAME="Fury"                     # Name used in log file names
SNSPD_DRIVER_TYPE="opus"              # 'opus' (real hardware) or 'virtual' (simulated)
SNSPD_TTY="/dev/ttyACM0"              # QOELEC serial device (prefer the /dev/serial/by-id path)
SNSPD_SERIAL=""                       # QOELEC USB serial number; empty uses the first one found
SNSPD_T2K_THERM_CH="1"                # Thermometer input of the 2 K stage
SNSPD_T2K_CAL="T160.cal"              # Calibration curve of the 2 K stage
SNSPD_T40K_THERM_CH="0"               # Thermometer input of the 40 K stage
SNSPD_T40K_CAL="T159.cal"             # Calibration curve of the 40 K stage
SNSPD_MAX_BIAS_UA=""                  # Required: per-channel bias limits in uA from the unit's datasheet
SNSPD_BIAS_RAMP_STEP_UA="0.5"         # Largest single bias step in uA
SNSPD_MAX_OPERATING_T_K="3.5"         # Refuse nonzero bias above this 2 K stage temperature (0 disables)
SNSPD_POLL_INTERVAL_S="5"             # Background temperature/count poll period in seconds
SNSPD_LOG_DIR=""                      # Host directory for daily <name>_log_<date>.dat files (empty: off)
```

`SNSPD_MAX_BIAS_UA` has no default because the limits differ between SNSPD units. Take them from your unit's datasheet, for example `1=12.2,2=12.1`. `run.sh` refuses to start without them (the virtual driver doesn't need them). The agent never sets a bias above the limit: when a request is at the limit, it rounds down to the DAC step below it (about 0.049 uA steps) instead of to the nearest step.

When `SNSPD_DRIVER_TYPE=opus`, the QOELEC is passed through to the container (`--device` + `dialout` group) at its resolved device path. With `SNSPD_DRIVER_TYPE=virtual`, no hardware is required, which is useful for testing the deployment.

### 4. Run the Application
Make the script executable and run it:

```bash
chmod +x run.sh
SNSPD_TTY=/dev/serial/by-id/usb-<qoelec-id>-if00 SNSPD_MAX_BIAS_UA="1=12.2,2=12.1" ./run.sh
```

To keep the daily log files the old logger wrote:

```bash
SNSPD_TTY=/dev/serial/by-id/usb-<qoelec-id>-if00 SNSPD_MAX_BIAS_UA="1=12.2,2=12.1" SNSPD_LOG_DIR=$HOME/snspd-logs ./run.sh
```

To run against a simulated module instead of real hardware:

```bash
SNSPD_DRIVER_TYPE=virtual ./run.sh
```

Follow the logs with:

```bash
docker logs -f snspd_agent
```

## After Deploying

- Read the temperatures and the current bias before setting any bias.
- Check that `T2K` reads about 1.7 K and `T40K` about 30 K when the system is cold. If they are swapped, exchange the `SNSPD_T2K_*` and `SNSPD_T40K_*` settings, moving each `.cal` file together with its input.
- Restarting the container does not change the detector bias.

### Notes
- This setup assumes the environment is Linux-only due to complications with serial port mapping on Windows.
- See the `snspd-agent` repository for the capability contract and the safety behaviour.
