#!/bin/bash

# This script runs a SonarQube scan on a project.
#
# It can be used to perform a full scan of a directory or to import a SARIF report, or both.
#
# Usage:
#   ./sonar_scan.sh -k <project_key> [-r <scan_path>] [-i <sarif_report_path>]
#
# Options:
#   -k <project_key>:         SonarQube project key (required).
#   -r <scan_path>:           Path to the directory to scan.
#   -i <sarif_report_path>:   Path to a SARIF report to import.
#
# You must provide -k and at least one of -r or -i.
#
# Environment Variables:
#   SONAR_AUTH_TOKEN:   The authentication token for SonarQube.
#   SONARQUBE_URL:      The URL of the SonarQube server.
#
# Examples:
#   # Perform a full scan of the current directory
#   ./sonar_scan.sh -k my-project -r .
#
#   # Import a SARIF report
#   ./sonar_scan.sh -k my-project -i /path/to/report.sarif
#
#   # Perform a scan and import a SARIF report
#   ./sonar_scan.sh -k my-project -r . -i /path/to/report.sarif

usage() {
    echo "Usage: $0 -k <project_key> [-r <scan_path>] [-i <sarif_report_path>]"
    echo "  -k: SonarQube project key (required)."
    echo "  -r: Path to the directory to scan."
    echo "  -i: Path to a SARIF report to import."
    echo "You must provide -k and at least one of -r or -i."
    exit 1
}

PROJECT_KEY=""
SCAN_PATH=""
SARIF_PATH=""

while getopts "k:r:i:h" opt; do
    case ${opt} in
        k) PROJECT_KEY=${OPTARG} ;; 
        r) SCAN_PATH=${OPTARG} ;; 
        i) SARIF_PATH=${OPTARG} ;; 
        h) usage ;; 
        *) usage ;; 
    esac
done

# Validate arguments
if [ -z "${PROJECT_KEY}" ] || { [ -z "${SCAN_PATH}" ] && [ -z "${SARIF_PATH}" ]; }; then
    usage
fi

# Determine the base path to mount and the SARIF filename for the scanner
MOUNT_PATH=""
SCANNER_SARIF_FILENAME=""

if [ -n "${SCAN_PATH}" ]; then
    # -r is present, it defines the mount path
    MOUNT_PATH=$(realpath "${SCAN_PATH}")
    if [ -n "${SARIF_PATH}" ]; then
        # if -i is also present, we need its basename relative to the mount path
        # This assumes the sarif path is inside the scan path
        SCANNER_SARIF_FILENAME=$(realpath --relative-to="${MOUNT_PATH}" "${SARIF_PATH}")
    fi
else
    # Only -i is present. Its directory is the mount path.
    MOUNT_PATH=$(realpath $(dirname "${SARIF_PATH}"))
    SCANNER_SARIF_FILENAME=$(basename "${SARIF_PATH}")
fi

# Build scanner options
if [ -z "${SONAR_AUTH_TOKEN}" ]; then
    echo "Error: SONAR_AUTH_TOKEN environment variable is not set."
    exit 1
fi
AUTH_TOKEN=${SONAR_AUTH_TOKEN}
SONARQUBE_URL=${SONARQUBE_URL:-"sonarqube:9000"}

SONAR_SCANNER_OPTS="-Dsonar.projectKey=${PROJECT_KEY}"

# If we are not doing a full scan, we should tell the scanner where the sources are.
# This is crucial for a pure import so SonarQube can find the files referenced in the SARIF report.
if [ -z "${SCAN_PATH}" ]; then
    SONAR_SCANNER_OPTS="${SONAR_SCANNER_OPTS} -Dsonar.sources=."
fi

if [ -n "${SCANNER_SARIF_FILENAME}" ]; then
    SONAR_SCANNER_OPTS="${SONAR_SCANNER_OPTS} -Dsonar.sarifReportPaths=${SCANNER_SARIF_FILENAME}"
fi

# Run Docker
docker run \
    --rm \
    --network devsecops-tools_default \
    -e SONAR_HOST_URL="http://${SONARQUBE_URL}" \
    -e SONAR_SCANNER_OPTS="${SONAR_SCANNER_OPTS}" \
    -e SONAR_TOKEN="${AUTH_TOKEN}" \
    -v "${MOUNT_PATH}:/usr/src" \
    sonarsource/sonar-scanner-cli

exit $?