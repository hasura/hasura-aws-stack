# hasura-aws-stack

## Setup Hasura on Fargate

1. Go to ECS in AWS Console.
2. Create a ECS cluster on Fargate with required specs.
3. Create a Task Definition with Hasura GraphQL Engine container and environment variables.
4. Add the Task to your ECS cluster as a service.

If you are want to use multiple-instances/auto-scale, you will need to choose an ALB as the load balancer.

## Local Dev

1. Git clone this repo:

```
$ git clone git@github.com:hasura/hasura-aws-stack.git
$ cd hasura-aws-stack
$ # You are now in the project directory
```

2. Run Hasura using docker-compose [ref](https://github.com/hasura/graphql-engine/tree/master/install-manifests/docker-compose) :

```
In project directory:

$ mkdir tmp && cd tmp
$ wget https://raw.githubusercontent.com/hasura/graphql-engine/master/install-manifests/docker-compose/docker-compose.yaml
$ docker-compose up -d
```

You can visit the Hasura console at `http://localhost:8080/console`.

3. Apply migrations locally

```
In project directory;

$ cd hasura
$ hasura migrate apply
```

## CI/CD with CircleCI

We want to keep 3 environments in the cloud:

1. Dev
2. Staging
3. Prod

The CI/CD system will deploy the application to each environment based on the branch on which the code is pushed: 

| _branch_ | _environment_ |
|----------|---------------|
| master   | dev           |
| staging  | staging       |
| prod     | prod          |

1. Start by creating a project in CircleCI.

2. Add your git repo in your CircleCI dashboard. This repo has all the CircleCI configuration in `.circleci/config.yml` file.

3. Configure environment variables in your CircleCI project from the dashboard. This example requires the following environment variables:

    _HASURA_DEV_ENDPOINT_

    _HASURA_DEV_ACCESS_KEY_

    _HASURA_STG_ENDPOINT_

    _HASURA_STG_ACCESS_KEY_

    _HASURA_PROD_ENDPOINT_

    _HASURA_PROD_ACCESS_KEY_

4. Git push or merge PR to master branch. This will deploy to dev environment.

5. Once you have tested the dev environment, you can promote to staging and prod environments by merging dev with staging and staging with prod respectively.
