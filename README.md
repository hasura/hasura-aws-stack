# hasura-aws-stack

## Stack

- Hasura on ECS Fargate (auto-scale)
- RDS Postgres
- Lambdas for remote schemas and event triggers
- Docker for local dev
- CircleCI for CI/CD

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

$ cd local
$ docker-compose up -d
```

3. Start local development API server ( first make sure all dependencies are met for local API server):

```
In project directory:

$ # install dependencies for local API server for e.g. all remote schemas and event triggers
$ # cd remote-schemas/account-schema
$ # npm i

$ cd local
$ node localDevelopment.js
```

4. Apply migrations locally

```
In project directory;

$ cd hasura
$ hasura migrate apply
```

5. Start the console

```
In project directory:

$ cd hasura
$ hasura console
```

### Local Dev - Event Triggers

1. Create a new folder in `event-triggers` folder:

```
In project directory:

$ cd event-triggers
$ mkdir echo
```

2. Write your function in `echo/index.js`. Make sure you export one function. Ref: [echo](event-triggers/echo/index.js)

3. Add corresponding endpoint in local development API server. Ref: [localDevelopment](local/localDevelopment.js)

4. Start the local development API server:

```
In project directory:

$ cd local
$ node localDevelopment.js
```

5. Add event trigger URL as environment variable in `local/event-triggers.env`. Ref: [event-triggers.env](local/event-triggers.env)

6. Restart Hasura (for refreshing environment variables):

```
In project directory:

$ cd local
$ docker-compose down
$ docker-compose up -d
```

7. Add event trigger through Hasura console using the above environment variable as `WEBHOOK_URL`.

### Local Dev - Remote Schemas

1. Create a new folder in `remote-schemas` folder:

```
In project directory:

$ cd remote-schemas
$ mkdir account-schema
```

2. Write your graphql functions in `account-schema/index.js`. Make sure you export the typedefs and resolvers. Ref: [account](remote-schemas/account-schema/index.js)

3. Add corresponding server setup in local development API server. Ref: [localDevelopment](local/localDevelopment.js)

4. Start the local development API server:

```
In project directory:

$ cd local
$ node localDevelopment.js
```

5. Add remote schema URL as environment variable in `local/remote-schemas.env`. Ref: [remote-schemas.env](local/remote-schemas.env)

6. Restart Hasura (for refreshing environment variables):

```
In project directory:

$ cd local
$ docker-compose down
$ docker-compose up -d
```

7. Add remote schema through Hasura console using the above environment variable as `GraphQL Server URL`.

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
