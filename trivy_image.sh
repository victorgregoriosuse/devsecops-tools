#!/bin/bash

# This script scans a Docker image for vulnerabilities using Trivy.
#
# Usage:
#   ./trivy_image.sh <image_name>
#
# Environment Variables:
#   TRIVY_REPORTS_DIR: Directory to save the Trivy report. Defaults to "$(pwd)/Reports".
#   TRIVY_IMAGE: The Trivy image to use for scanning. Defaults to "dp.apps.rancher.io/containers/trivy:0.67.2".
#   TRIVY_TIMEOUT: Timeout for the Trivy scan. Defaults to "30m".
#
# Example:
#   ./trivy_image.sh my-app:latest

if [ -z "$1" ]; then
    echo "Usage: $0 <image_name>"
    exit 1
fi

SCRIPT_DIR=$(dirname "$0")
OUTPUT_DIR=${TRIVY_REPORTS_DIR:-"$(pwd)/Reports"}
TRIVY_IMAGE=${TRIVY_IMAGE:-dp.apps.rancher.io/containers/trivy:0.67.2}
TRIVY_TIMEOUT=${TRIVY_TIMEOUT:-30m}
#TRIVY_SEVERITY=${TRIVY_SEVERITY:-UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL}

ARG_IMG="$1"

REPORT_FILENAME=$(echo "$ARG_IMG" | tr '/:' '_')

docker pull $ARG_IMG

docker run \
    --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v $OUTPUT_DIR:/output \
    $TRIVY_IMAGE image \
    --timeout $TRIVY_TIMEOUT \
    --format sarif \
    --output "/output/$REPORT_FILENAME.sarif" "$ARG_IMG" 
#   --severity $TRIVY_SEVERITY \

exit $?