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
    log_err "Usage: $0 -i <image_name> {-t|-d} [-k <sonar_project_key>]"
    log_err "  -t: Scan with Trivy"
    log_err "  -d: Scan with Docker Scout"
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

SCAN_TOOL=""

while getopts "k:i:htd" opt; do
    case ${opt} in
        k) SONAR_PROJECT_KEY_OVERRIDE=${OPTARG} ;;
        i) SCAN_IMAGE=${OPTARG} ;; 
        t) SCAN_TOOL="trivy" ;;
        d) SCAN_TOOL="dockerscout" ;;
        h) usage ;; 
        \?) usage ;;
        *) echo "unhandled option: $opt"; usage ;;
    esac
done

#
# PRE-FLIGHT CHECKS
#

if [ -z "${SONAR_AUTH_TOKEN}" ]; then
    log_err "Error: SONAR_AUTH_TOKEN environment variable is not set."
    exit 1
fi

if [ -z "$SCAN_IMAGE" ]; then
    usage
fi

if [ -z "$SCAN_TOOL" ]; then
    log_err "Error: A scan tool must be specified with either -t (Trivy) or -d (Docker Scout)."
    usage
fi

#
# SCAN TO SARIF
#

SARIF_CLEAN_NAME=$(echo "$SCAN_IMAGE" | tr '/:' '-' | tr -c '[:alnum:]-_' '_')
mkdir -p "$TRIVY_REPORTS_DIR"

# seed local docker with image
log_info "Pulling image: $SCAN_IMAGE"
docker pull "$SCAN_IMAGE"

if [ "$SCAN_TOOL" == "trivy" ]; then
    SARIF_FILENAME="${SARIF_CLEAN_NAME}_Trivy.sarif"
    # run trivy scan connecting to docker daemon via socket for seeded image
    log_info "Scanning image '$SCAN_IMAGE' with Trivy..."
    docker run \
        --rm \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v "$TRIVY_REPORTS_DIR:/reports" \
        "$TRIVY_IMAGE" image \
        --timeout "$TRIVY_TIMEOUT" \
        --format sarif \
        --output "/reports/$SARIF_FILENAME" "$SCAN_IMAGE"
elif [ "$SCAN_TOOL" == "dockerscout" ]; then
    SARIF_FILENAME="${SARIF_CLEAN_NAME}_DockerScout.sarif"
    log_info "Scanning image '$SCAN_IMAGE' with Docker Scout..."
    docker scout cves "$SCAN_IMAGE" --format sarif --output "$TRIVY_REPORTS_DIR/$SARIF_FILENAME"
else
    log_err "Internal error: Unknown scan tool '$SCAN_TOOL'"
    exit 1
fi

RETVAL=$?

if [ $RETVAL -ne 0 ]; then
    log_err "Scan failed for image: $SCAN_IMAGE"
    exit $RETVAL
else
    log_info "Scan completed successfully."
    log_info "Report saved to: $TRIVY_REPORTS_DIR/$SARIF_FILENAME"
fi

#
# SONARQUBE IMPORT
#

# name project key the same as sarif clean name
if [ -n "$SONAR_PROJECT_KEY_OVERRIDE" ]; then
    SONAR_PROJECT_KEY="$SONAR_PROJECT_KEY_OVERRIDE"
else
    SONAR_PROJECT_KEY="${SARIF_CLEAN_NAME}"
fi

# sonar scanner cli options
SONAR_SCANNER_OPTS="-Dsonar.projectKey=${SONAR_PROJECT_KEY} -Dsonar.sources=. -Dsonar.sarifReportPaths=${SARIF_FILENAME}"

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

if [ "$SCAN_TOOL" == "dockerscout" ]; then
    log_info "To free up space, you can prune the Docker Scout cache and SBOMs with the following command:"
    echo
    echo "    docker scout cache prune --sboms --force"
    echo
fi

exit $RETVAL