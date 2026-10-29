#!/bin/bash

# Set environment variables (override any of them from the shell if needed)
CONTAINER_NAME="${CONTAINER_NAME:-snspd_agent}"
IMAGE_NAME="${IMAGE_NAME:-ghcr.io/measurement-plane/snspd-agent:latest}"
BROKER_URL="${BROKER_URL:-nats://172.17.0.1:4222}"
ENDPOINT="${ENDPOINT:-/snspd/fury}"
SNSPD_NAME="${SNSPD_NAME:-Fury}"
SNSPD_DRIVER_TYPE="${SNSPD_DRIVER_TYPE:-opus}"
SNSPD_TTY="${SNSPD_TTY:-/dev/ttyACM0}"
SNSPD_SERIAL="${SNSPD_SERIAL:-}"
SNSPD_T2K_THERM_CH="${SNSPD_T2K_THERM_CH:-1}"
SNSPD_T2K_CAL="${SNSPD_T2K_CAL:-T160.cal}"
SNSPD_T40K_THERM_CH="${SNSPD_T40K_THERM_CH:-0}"
SNSPD_T40K_CAL="${SNSPD_T40K_CAL:-T159.cal}"
# Required for real hardware: per-channel bias limits in uA from this unit's datasheet,
# e.g. "1=12.2,2=12.1". Limits differ between units, so there is no default.
SNSPD_MAX_BIAS_UA="${SNSPD_MAX_BIAS_UA:-}"
SNSPD_BIAS_RAMP_STEP_UA="${SNSPD_BIAS_RAMP_STEP_UA:-0.5}"
SNSPD_MAX_OPERATING_T_K="${SNSPD_MAX_OPERATING_T_K:-3.5}"
SNSPD_POLL_INTERVAL_S="${SNSPD_POLL_INTERVAL_S:-5}"
SNSPD_LOG_DIR="${SNSPD_LOG_DIR:-}"

# Checked before the running container is touched.
if [ "$SNSPD_DRIVER_TYPE" != "virtual" ] && [ -z "$SNSPD_MAX_BIAS_UA" ]; then
    echo "Error: set SNSPD_MAX_BIAS_UA to this SNSPD unit's per-channel bias limits in uA from its datasheet, e.g. SNSPD_MAX_BIAS_UA=1=12.2,2=12.1. Exiting."
    exit 1
fi

# Only pass the QOELEC through when talking to real hardware; the 'virtual'
# driver needs no device access. The device is mapped to its resolved path
# (e.g. from a /dev/serial/by-id link) so the driver's USB VID/PID discovery
# reads the matching sysfs entry inside the container.
DEVICE_ARGS=()
if [ "$SNSPD_DRIVER_TYPE" != "virtual" ]; then
    SNSPD_DEV="$(readlink -f "$SNSPD_TTY")"
    if [ ! -e "$SNSPD_DEV" ]; then
        echo "Error: SNSPD device $SNSPD_TTY not found. Exiting."
        exit 1
    fi
    DEVICE_ARGS=(--device="$SNSPD_DEV:$SNSPD_DEV" --group-add dialout)
fi

# Optionally keep writing the daily <name>_log_<date>.dat files on the host.
LOG_ARGS=()
if [ -n "$SNSPD_LOG_DIR" ]; then
    mkdir -p "$SNSPD_LOG_DIR"
    LOG_ARGS=(-v "$SNSPD_LOG_DIR:/logs" -e SNSPD_LOG_DIR=/logs)
fi

# Stop and remove any running container with the same name
echo "Stopping and removing existing container (if any)..."
docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true

# Pull the latest pre-built image
echo "Pulling the latest image..."
if ! docker pull "$IMAGE_NAME"; then
    echo "Error: Failed to pull the image. Exiting."
    exit 1
fi

# Run the container
echo "Starting the container..."
docker run -d --name "$CONTAINER_NAME" \
    "${DEVICE_ARGS[@]}" \
    "${LOG_ARGS[@]}" \
    -e BROKER_URL="$BROKER_URL" \
    -e ENDPOINT="$ENDPOINT" \
    -e SNSPD_NAME="$SNSPD_NAME" \
    -e SNSPD_DRIVER_TYPE="$SNSPD_DRIVER_TYPE" \
    -e SNSPD_SERIAL="$SNSPD_SERIAL" \
    -e SNSPD_T2K_THERM_CH="$SNSPD_T2K_THERM_CH" \
    -e SNSPD_T2K_CAL="$SNSPD_T2K_CAL" \
    -e SNSPD_T40K_THERM_CH="$SNSPD_T40K_THERM_CH" \
    -e SNSPD_T40K_CAL="$SNSPD_T40K_CAL" \
    -e SNSPD_MAX_BIAS_UA="$SNSPD_MAX_BIAS_UA" \
    -e SNSPD_BIAS_RAMP_STEP_UA="$SNSPD_BIAS_RAMP_STEP_UA" \
    -e SNSPD_MAX_OPERATING_T_K="$SNSPD_MAX_OPERATING_T_K" \
    -e SNSPD_POLL_INTERVAL_S="$SNSPD_POLL_INTERVAL_S" \
    "$IMAGE_NAME" || {
        echo "ERROR: Failed to start container."
        exit 1
    }
echo "Started. Logs: docker logs -f $CONTAINER_NAME"
