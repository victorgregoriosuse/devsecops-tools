#!/bin/bash

#
# LOGGING
#

SCRIPT_NAME=$(basename "$0")


log_info() {
    echo "===== [INFO]($SCRIPT_NAME) $1"
}

log_err() {
    echo "===== [ERROR]($SCRIPT_NAME) $1" >&2
}

usage() {
    log_err "Usage: $0 -i <image_name>"
    exit 1
}

#
# CONFIG
#

TRIVY_REPORTS_DIR=${TRIVY_REPORTS_DIR:-"$(pwd)/reports"}
TRIVY_IMAGE=${TRIVY_IMAGE:-"dp.apps.rancher.io/containers/trivy:0.67.2"}
TRIVY_TIMEOUT=${TRIVY_TIMEOUT:-"30m"}
SONAR_URL=${SONARQUBE_URL:-"sonarqube:9000"}
SONAR_DOCKER_NETWORK=${SONAR_DOCKER_NETWORK:-"devsecops-tools_default"} # Default network created by docker-compose

#
# ARGUMENT PARSING
#

while getopts "r:i:h" opt; do
    case ${opt} in
        i) SCAN_IMAGE=${OPTARG} ;; 
        h) usage ;; 
        *) usage ;; 
    esac
done

#
# PRE-FLIGHT CHECKS
#

if [ -z "${SONAR_AUTH_TOKEN}" ]; then
    log_err "Error: SONAR_AUTH_TOKEN environment variable is not set."
    exit 1
fi

#
# TRIVY SCAN TO SARIF
#

if [ -z "$SCAN_IMAGE" ]; then
    usage
fi

TRIVY_SARIF_CLEAN_NAME=$(echo "$SCAN_IMAGE" | tr '/:' '-' | tr '/.' '_')
mkdir -p "$TRIVY_REPORTS_DIR"
TRIVY_SARIF_FILENAME="$TRIVY_SARIF_CLEAN_NAME.sarif"

# seed local docker with image
log_info "Pulling image: $SCAN_IMAGE"
docker pull "$SCAN_IMAGE"

# run trivy scan connecting to docker daemon via socket for seeded image
log_info "Scanning image '$SCAN_IMAGE' with Trivy..."
docker run \
    --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$TRIVY_REPORTS_DIR:/reports" \
    "$TRIVY_IMAGE" image \
    --timeout $TRIVY_TIMEOUT \
    --format sarif \
    --output "/reports/$TRIVY_SARIF_FILENAME" "$SCAN_IMAGE"

RETVAL=$?

if [ $RETVAL -ne 0 ]; then
    log_err "Trivy scan failed for image: $SCAN_IMAGE"
    exit $RETVAL
else
    log_info "Trivy scan completed successfully."
    log_info "Report saved to: $TRIVY_REPORTS_DIR/$TRIVY_SARIF_FILENAME"
fi

#
# SONARQUBE IMPORT
#

# name project key the same as sarif clean name
SONAR_PROJECT_KEY="${TRIVY_SARIF_CLEAN_NAME}"

# sonar scanner cli options
SONAR_SCANNER_OPTS="-Dsonar.projectKey=${SONAR_PROJECT_KEY} -Dsonar.sources=. -Dsonar.sarifReportPaths=${TRIVY_SARIF_FILENAME}"

log_info "Importing SARIF report to SonarQube project: ${SONAR_PROJECT_KEY}"
docker run \
    --rm \
    --network "$SONAR_DOCKER_NETWORK" \
    -e SONAR_HOST_URL="http://${SONAR_URL}" \
    -e SONAR_SCANNER_OPTS="${SONAR_SCANNER_OPTS}" \
    -e SONAR_TOKEN="${SONAR_AUTH_TOKEN}" \
    -v "$TRIVY_REPORTS_DIR:/usr/src" \
    sonarsource/sonar-scanner-cli

RETVAL=$?

if [ $RETVAL -ne 0 ]; then
    log_err "SonarQube import failed."
    exit $RETVAL
else
    log_info "SonarQube import completed successfully as project: ${SONAR_PROJECT_KEY}."
fi

exit $RETVAL