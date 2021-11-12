# Alembic docker scripts

Alembic command requires a predefined folder structure which is created on running `alembic init [dir]`. This creates unnecessary overhead. This repo provides scripts that creates the folder structure in dockerfile and runs alembic as a docker container, thereby it is not necessary to have any directory structure

***Prerequisite***
1. Docker (18.09 or higher)
2. unix (linux/macos, windows may not work)

***Navigate to specific repo (containing schema dir) before running commands***

These tools can be used to run alembic commands and create new migration scripts.

## Run alembic commands
`$ /path/to/alembic_docker/run_alembic.sh [cmd]`

### Different alembic commands
    1. heads (current head)
    2. upgrade head (run migrations)
    3. history (displays the sequence of migrations that ran)
    for more commands `$ /path/to/alembic_docker/run_alembic.sh -h`

## Create migration scripts  
**This will push the generated script to ./schema/alembic/versions**

`$ /path/to/alembic_docker/create_migrations.sh [script-name]`

### Configuration
1. Default values are
    * DB_USERNAME=root
    * DB_PASSWORD=password
    * DB_HOST=mysql
    * DB_NAME=root
    * DB_NETWORK=bridge (this is useful if you are running mysql in a docker container)
    * DB_PORT=3306
    * VERSIONS_DIR=./schema/alembic/versions
    

To change the values and run commands, set as 

`$ DB_HOST=localhost DB_USERNAME=root DB_PASSWORD=password /path/to/alembic_docker/run_alembic.sh upgrade head`

## TIPS
1. You can set environment variables permanently in `.bashrc` as
    ```
    export DB_USERNAME='user'
    export DB_PASSWORD='password'
    export DB_HOST='localhost'
    export DB_NAME='root'
    ```
2. Add above scripts to the PATH as `export PATH=$PATH:/path/to/alembic_docker`
