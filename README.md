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

**Note on Trivy Image**

By default, when using Trivy (`-t`), the script uses an image from the Rancher Application Collection. Pulling this image requires authentication. You will need to perform a `docker login dp.apps.rancher.io` with an access token from https://apps.rancher.io/settings/access-tokens.

Alternatively, you can change the `TRIVY_IMAGE` variable in the `CONFIG` section of the `scan_image.sh` script to use a different Trivy container image.

**Note on Docker Scout**

When using Docker Scout (`-d`), it generates and caches SBOMs (Software Bill of Materials) for the images it analyzes. Over time, this cache can grow and consume significant disk space.

To free up space, you can prune the Docker Scout cache and SBOMs with the following command:

```bash
docker scout cache prune --sboms --force
```

**Usage:**

Before running the script, you must set the `SONAR_AUTH_TOKEN` environment variable to your SonarQube access token.

```bash
export SONAR_AUTH_TOKEN=<your_sonarqube_token>
./scan_image.sh -i <image_name> {-t|-d} [-k <sonar_project_key>]
```
