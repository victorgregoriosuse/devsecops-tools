# DevSecOps Tools

This repository contains scripts to integrate Trivy vulnerability scans with SonarQube.

## Workflow

The following steps describe how to launch SonarQube, scan a Docker image for vulnerabilities using Trivy, and import the results into SonarQube.

### 1. Launch SonarQube

The `compose.yml` file starts a SonarQube instance along with a PostgreSQL database.

**To launch SonarQube:**

```bash
docker-compose up -d
```

SonarQube will be available at [http://localhost:9000](http://localhost:9000).

### 2. Scan an Image with Trivy

The `trivy_image.sh` script scans a Docker image and generates a SARIF report.

**Usage:**

```bash
./trivy_image.sh <image_name>
```

This will create a SARIF file in the `reports` directory. For example, scanning the image `my-app:latest` will create a report named `reports/my-app_latest.sarif`.

### 3. Import the SARIF Report into SonarQube

The `sonar_scan.sh` script imports the SARIF report into a SonarQube project.

**Usage:**

Before running the script, you need to create a project in SonarQube and get a project key. You must also set the `SONAR_AUTH_TOKEN` environment variable to your SonarQube access token.

```bash
export SONAR_AUTH_TOKEN=<your_sonarqube_token>
./sonar_scan.sh -k <project_key> -i <path_to_sarif_report>
```

**Example:**

```bash
./sonar_scan.sh -k my-project -i reports/my-app_latest.sarif
```

This will import the Trivy scan results into the "my-project" project in SonarQube.
