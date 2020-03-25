# HEIOT
HEIOT is an IoT platform to manage IoT devices and their delivered data.
The user can overlook all devices in lists grouped by the actual condition distinguishing between the need of the platform's manager to take further actions. The user is enabled to create tags and masterdata by her-/himself in order to group the devices semantically.
Moreover, there is a detailed view of each device where all data is displayed and visualized by interactive charts and tables.
The platform also includes an analytical service to detect anomalies in the device's data.

HEIOT was a project ("ISE project") implemented by a group of students from the University of Heidelberg.

## Deploying the ISE project

The deployment of the ISE project is grouped in four distinct steps:

1. Bootstrapping TLS certificates (bootstrap)
2. Launching the docker registry (registry)
3. Launching the proxy and monitoring infrastructure (proxy)
4. Launching the ise application (ise)

Each step has it's own appropriatly named folder.

Launching the docker registry and the ise application in two distinct steps limits the fault domain of a failed ise deployment to only ise services.
This is crucial to prevent a deadlock situation where we need a docker registry to publish a corrected image too, to prevent a web server from crashing which hosts the registry. It would be preferable to host this service on a different server completely.

### Prerequisites

- Install docker-compose
- DNS is configured and a domain is pointing on this publicly reachable server.

### Bootstrapping

The Bootstrapping process is necessary to launch a fully featured docker registry.
Clients expect a TLS encripted connection or would need special setup to suppress warnings.
We use the lets encrypt service to get our publicly signed certificates.

#### Folder structure

- **docker-compose.yml**:
  This file describes two services as a docker-compose file.
  The certbot service handles the protocoll to aqcuire a valid certificate from lets encrypt.
  The nginx service is the publicly reachable web server with which the lets encrypt services can communicate.
  Data exchange between these services is handled by two shared folders.
  One is used for the files which the webserver must present and one is used to store the aquired certificate.

- **prod/nginx/nginx.conf**:
  The nginx server configuration.

- **init-letsencrypt.sh**:
  A script to sequence all actions to aquire the certificate.

#### Usage

Execute these steps on the server, which will be responsible for ingesting traffic and terminating the TLS-connections.

1. Change the parameters in the init-letsencrypt.sh script.
  Consider setting the staging option to '1'.
  The amount of certificates issued by let sencrypt is rate limitid to 7 per week on a rolling basis.
2. Make the script executable.
  ```bash
    chmod +x init-letsencrypt.sh
  ```
3.  Execute the script and follow the steps.

  ```bash
    ./init-letsnecrypt.sh
  ```

---

#### Script explanation

1. Download the best practice tls certificate configuration parameters.
2. Create a dummy certificate. This is necessary to start nginx, which won't start without a valid certificate file (it mustn't be signed by a certificate authority).
3. Start nginx.
4. Delete the dummy certificate.
5. Construct the necessary parameters for requesting a certificate.
6. Start certbot with the parameters from the previous step
7. Reload nginx with the now available certificate
8. Kill the nginx container.

---

### Registry

Deploying the registry, provides the user with a private docker registry and an UI to manage.
It is accessible on *heieducation.ifi.uni-heidelberg.de:5000*.
The access is limited by basic authentication.
A user or docker-daemon have to login before they can publish or pull images.

#### Folder structure

- **docker-compose.proxy.yml**:
  This docker-compose file describes the nginx instance which handles the docker registry

- **docker-compose.registry.yml**:
  This docker-compose file describes the docker registry and docker registry ui service.

- **proxy/{{ }}**:
  nginx.Dockerfile describes the build instructions to create the nginx instance described in docker-compose.proxy.yml.
  It loads nginx.conf, the nginx configuration, and the folder htpasswd, which contains the password hashes for access control.

#### Usage

1. Build the nginx docker image.

  ```bash
    docker-compose -f docker-compose.proxy.yml build
  ```

2. Launch all services.

  ```bash
    docker-compose -f docker-compose.proxy.yml -f docker-compose.registry.yml up -d
  ```

3. Verify funtionality by opening *heieducation.ifi.uni-heidelberg.de:5000* and pushing and pulling a image to the registry.

### Proxy

This folder contains the `nginx` reverse proxy which handels the staging and production environment. This includes a
We deploy `cadvisor`, for gathering container metrics, and and `prometheus`, for storing container metrics, as well.
This allows us to gather metrics even during deployments.

#### Folder structure

- **htpasswd/**
  The password hashes used for authorization.

- **nginx.conf**
  The `nginx` configuration.

- **nginx.Dockerfile**
  The `Dockerfile` necessary for building the `nginx` container image.

- **docker-compose.yml**
  `docker-compose` configuration which creates the reverse proxy, the `lets-encrypt-certificate-renewal-daemon` and the networks which the production and staging environment use.

#### Usage

  Switch into the folder and start the execution with

  ```bash
   docker-compose up -d --build
  ```

### ISE

This is the step in the deployment where differentiate between the staging and release deployment. The steps made before fall in the category of common infrastructure.

The services in the ISE-deployment fall in 4 different categories.
The `backend`, `frontend`, `database-tooling` and the `data-crawler`.
They are all included in the same `docker-compose-file`.


#### Folder structure

- **docker-compose.yml**:
  Compose file describing the different services of the ise project.

- **pgadmin4/servers.json**:
  Configuration file to preconfigure pgadmin on the first start with the parameters of the postgresql instance.

- **.env**:
  The file containing all configuration parameters for the application. There is a sperate one for staging and for the release deployment.

#### Usage

1. Build the images for the frontend and backend services on a dev machine or CI-service and push them to the new registry

  ```bash
    # on the machine that will build and push the images
    docker login -u ISE2019 -p ****** heieducation.ifi.uni-heidelberg.de:5000
  ```

  ```bash
    # in the root directory of the ise_2019_frontend repository
    docker build . --target prod --tag heieducation.ifi.uni-heidelberg.de:5000/ise_2019_frontend_{staging/release}

    docker push heieducation.ifi.uni-heidelberg.de:5000/ise_2019_frontend_{staging/release}
  ```

  ```bash
    # in the root directory of the ise_2019_backend repository
    docker build . --target prod --tag heieducation.ifi.uni-heidelberg.de:5000/ise_2019_backend_{staging/release}

    docker push heieducation.ifi.uni-heidelberg.de:5000/ise_2019_backend_{staging/release}
  ```

1. Set environment variables for the shell.

    ```bash
    # on the shell session which will deploy the service
    export COMPOSE_HTTP_TIMEOUT=240
    export COMPOSE_PROJECT_NAME=staging
    export VERSION=staging
    ```

    These ensure that the correct docker images get pulled and the correct containers get restarted.

2. Pull the images.

  ```bash
    docker-compose pull
  ```

3. Start the services.

  ```bash
    docker-compose up -d
  ```

4. Verify function by visiting:
   - *heieducation-staging.ifi.uni-heidelberg.de*
   - *heieducation-staging.ifi.uni-heidelberg.de/api*
   - *heieducation-*staging*.ifi.uni-heidelberg.de/pgadmin*

You have to repeat the *ISE* step again to deploy the release version.