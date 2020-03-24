# CI- & CD-Infrastructure

We use Bamboo as our CI&CD-tool.

All branches of the `ise_backend_2019` and `ise_frontend_2019` are automatically tested on our build server. Their master branches are deployed directly onto our staging environment.

Releases are made by merging onto the master branch of these repositories. Releases are build and deployed automatically as well.

## Overview
The two main repositories `ise_2019_backend` and `ise_2019_frontend` have multiple CI/CD-plans each.

The more general one is called "Staging {Frontend/Backend} Test" and its task is to test a branch with every push.

The second is called "Staging {Frontend/Backend} Test and Build (Master)". It is triggered by new commits on the master branch, typically after a pull request. It runs all tests and build, tag & pushes the docker images for the repository.

The plan "Staging ISE Deployment" is always called when one of the two "Staging {Frontend/Backend} Test and Build (Master)" plans finisher execution successfully. It deploys the current set of docker images to the server.

The "Staging {Frontend/Backend} Test and Build (Master)"- and "Staging ISE Deployment"-plans each exist in a "Release ..."-Variant. They behave identically with the difference that they watch only the release-branches of the repositories and deploy to the release environment.

Less integrated is the "Crawler Build"-Plan. It's main purpose is to make the crawler-docker-images automatically available after a push to it's repository.

## Staging {Backend/Frontend} Test - Plan

This plan tests the application by executing these tasks in order:
1. deleting all docker volumes
2. checking out the three repositories frontend, backend and dev_infra
3. pulling all container-images which are specified in the dev_infra repository
4. building the backend image
5. starting all docker images and executing `npm run docker-bamboo` which executes all tests and writes report files

Optional step for the frontend repository:
6. test building a docker image with production settings. This triggers a different set of optimisations, which could trigger a failure in the build step of the master-plan.

This plan will clean up the build directory after testing is completed or aborted with the following steps:
1. parsing the test results
2. stopping all running containers and removing them
3. deleting the test results to prevent contaminating future runs with stale data
4. deleting all docker networks
5. deleting all docker volumes
6. deleting the complete content of the building directory

## Staging {Backend/Frontend} Test and Build (Master)- Plan

This plan tests the application by executing an identical test procedure as the "Staging {Backend/Frontend} Test"-plan.\
Then it will start building the images:
1. checking out the current state of the master branch
2. executing a docker build command with the options: ```docker build . --target prod --tag heieducation.ifi.uni-heidelberg.de:5000/ise_2019_{backend/frontend}_staging:${bamboo.buildNumber}``` where {bamboo.buildNumber} is a monotonic increasing build number issued by bamboo
3. executing a docker build command with the options: ```docker build . --target prod --tag heieducation.ifi.uni-heidelberg.de:5000/ise_2019_{backend/frontend}_staging:latest```
4. pushing the docker image with the tag ```heieducation.ifi.uni-heidelberg.de:5000/ise_2019_{backend/frontend}_staging:${bamboo.buildNumber}```
5. pushing the docker image with the tag ```heieducation.ifi.uni-heidelberg.de:5000/ise_2019_{backend/frontend}_staging:latest```

This plan will clean up the build directory after building is completed or aborted.

Step 3, issuing a new build command with a different image tag, doesn't trigger a complete rebuild but will tag the docker-image from step 2 with the new tag as well.
These two tags allow us keep a log of all build docker-images, identified by its bamboo build id, while having a pointer to the most current one, labeled with ":latest".

## Staging ISE Deployment - Plan

Deploying the application is done via ssh directly on the target server.

1. Log into the target server and pull the current state of the "ise_2019_deployment"-repository.
2. Log into the target server and change into the ise_2019_deployment/4_ise subdirectory. Set these environment variables
		```
			export COMPOSE_HTTP_TIMEOUT=240
		  export COMPOSE_PROJECT_NAME={staging/release}
	    export VERSION={staging/release}
		```
		and pull the necessary images via `docker-compose pull`.
3. Log into the target server and change into the ise_2019_deployment/4_ise subdirectory. Set these environment variables
		```
			export COMPOSE_HTTP_TIMEOUT=240
		  export COMPOSE_PROJECT_NAME={staging/release}
			export VERSION={staging/release}
		```
		and start/update all services via `docker-compose up -d`.

	The functions of the environment variables are the following:
	- COMPOSE_HTTP_TIMEOUT: the target server isn't particularly powerfull. Crypto operations and uncompressing files max out the CPU and slow down the deployment process. Increasing the timeout for docker-compose operations prevents timeout induced failures.
	- COMPOSE_PROJET_NAME: this determines the name_prefix for all containers, networks and volumes deployed via docker-compose. This allows us to namespace the staging- and release-deployments and run them on the same operation system without interference.
	- VERSION: this determines which container-image should be used. Either the staging or release version.

## Crawler Build - Plan

This plan builds the crawler without testing it before:
1. checking out the current state of the master branch
2. executing a docker build command with the options: ```docker build . --target prod --tag heieducation.ifi.uni-heidelberg.de:5000/ise_2019_crawler:${bamboo.buildNumber}``` where {bamboo.buildNumber} is a monotonic increasing build number issued by bamboo
3. executing a docker build command with the options: ```docker build . --target prod --tag heieducation.ifi.uni-heidelberg.de:5000/ise_2019_crawler:latest```
4. pushing the docker image with the tag ```heieducation.ifi.uni-heidelberg.de:5000/ise_2019_crawler:${bamboo.buildNumber}```
5. pushing the docker image with the tag ```heieducation.ifi.uni-heidelberg.de:5000/ise_2019_crawler:latest}```

This plan will clean up the build directory after building is completed or aborted.

Step 3, issuing a new build command with a different image tag, doesn't trigger a complete rebuild but will tag the docker-image from step 2 with the new tag as well.
These two tags allow us keep a log of all build docker-images, identified by its bamboo build id, while having a pointer to the most current one, labeled with ":latest".