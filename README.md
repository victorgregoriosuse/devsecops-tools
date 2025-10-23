# DevSecOps Tools

This repository contains scripts to integrate container vulnerability scans with SonarQube using either Trivy or Docker Scout.

## Workflow

The following steps describe how to launch SonarQube, scan a Docker image for vulnerabilities using Trivy, and import the results into SonarQube.

### 1. Launch SonarQube

The `compose.yml` file starts a SonarQube instance along with a PostgreSQL database.

**To launch SonarQube:**

```bash
docker-compose up -d
```

* SonarQube will be available at [http://localhost:9000](http://localhost:9000).
* Login and change the admin password from the default.
* Configure an access token at [http://localhost:9000/account/security](http://localhost:9000/account/security).

### 2. Scan Image and Import to SonarQube

The `scan_image.sh` script orchestrates the entire process. It scans a specified Docker image with either Trivy or Docker Scout, generates a SARIF report, and then imports that report into a SonarQube project. If the project doesn't exist, SonarQube will create it automatically during the import.

**Usage:**

Before running the script, you must set the `SONAR_AUTH_TOKEN` environment variable to your SonarQube access token.

```bash
export SONAR_AUTH_TOKEN=<your_sonarqube_token>
./scan_image.sh -i <image_name> {-t|-d} [-k <sonar_project_key>]
```
