#!/bin/bash

if [[ $# -lt 1 ]]; then
  echo 'Usage: create_migration.sh "script-name"'
  exit 0
fi
rm Dockerfilealembicdockerfile > /dev/null 2>&1
tmpfile=$(mktemp Dockerfilealembicdockerfile)
exec 3>"$tmpfile"
cat <<EOFD >&3
# syntax = docker/dockerfile:1.3-labs
FROM alpine:3.14

# Install extra packages
RUN apk update
RUN apk add python3-dev
RUN apk add cmd:pip3
RUN apk add libffi-dev
RUN apk add gcc
RUN apk add g++
RUN apk add openssl-dev
RUN pip3 install alembic pymysql cryptography==2.7
RUN apk add netcat-openbsd

# Break cache
ARG INCUBATOR_VER=unknown
RUN INCUBATOR_VER=\${INCUBATOR_VER}

# Create alembic files
RUN mkdir -p /opt/schema/versions
ARG DB_USERNAME=root
ARG DB_PASSWORD=password
ARG DB_HOST=mysql
ARG VERSIONS_DIR=schema/alembic/versions
ARG DB_NAME=root
ARG DB_PORT=3306
ADD \${VERSIONS_DIR} /opt/schema/versions

# Create alembic.ini
COPY <<-EOF /opt/schema/alembic.ini

[alembic]
script_location = /opt/schema/
prepend_sys_path = .
sqlalchemy.url = mysql+pymysql://\${DB_USERNAME}:\${DB_PASSWORD}@\${DB_HOST}:\${DB_PORT}/\${DB_NAME}


[post_write_hooks]

[loggers]
keys = root,sqlalchemy,alembic

[handlers]
keys = console

[formatters]
keys = generic

[logger_root]
level = WARN
handlers = console
qualname =

[logger_sqlalchemy]
level = WARN
handlers =
qualname = sqlalchemy.engine

[logger_alembic]
level = INFO
handlers =
qualname = alembic

[handler_console]
class = StreamHandler
args = (sys.stderr,)
level = NOTSET
formatter = generic

[formatter_generic]
format = %(levelname)-5.5s [%(name)s] %(message)s
datefmt = %H:%M:%S
EOF

# create script.py.mako
COPY <<-EOF /opt/schema/script.py.mako
from alembic import op
import sqlalchemy as sa
\\\${imports if imports else \"\"}

revision = \\\${repr(up_revision)}
down_revision = \\\${repr(down_revision)}
branch_labels = \\\${repr(branch_labels)}
depends_on = \\\${repr(depends_on)}


def upgrade():
    \\\${upgrades if upgrades else \"pass\"}


def downgrade():
    \\\${downgrades if downgrades else \"pass\"}
EOF

# create env.py
COPY <<-EOF /opt/schema/env.py
from logging.config import fileConfig
from alembic import context
from sqlalchemy import engine_from_config
from sqlalchemy import pool
config = context.config
fileConfig(config.config_file_name)
target_metadata = None
def run_migrations_offline():
    url = config.get_main_option(\"sqlalchemy.url\")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={\"paramstyle\": \"named\"},
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online():
    connectable = engine_from_config(
        config.get_section(config.config_ini_section),
        prefix=\"sqlalchemy.\",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection, target_metadata=target_metadata
        )

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
EOF

WORKDIR /opt
EOFD
# check if alembic container is running
docker container inspect -f '{{.State.Running}}' alembic > /dev/null 2>&1
# if started, stop it
if [ $? -ne 1 ]; then
  docker rm -f alembic
fi
# delete image
docker image rm -f alembic > /dev/null 2>&1 && \
# rebuild image
DOCKER_BUILDKIT=1 docker build --rm -q -t alembic:latest -f Dockerfilealembicdockerfile --build-arg DB_HOST=${DB_HOST:-mysql} --build-arg DB_PASSWORD=${DB_PASSWORD:-password} --build-arg DB_USERNAME=${DB_USERNAME:-root} --build-arg DB_NAME=${DB_NAME:-root} --build-arg DB_PORT=${DB_PORT:-3306} --build-arg VERSIONS_DIR=${VERSIONS_DIR:-schema/alembic/versions} --build-arg INCUBATOR_VER=$(date +%Y%m%d-%H%M%S) . > /dev/null 2>&1
# start alembic container
docker run -it -d --name alembic alembic sh > /dev/null
# create new migration script and copy to schema/alembic/versions
docker exec -it alembic alembic -c schema/alembic.ini revision -m "$1" | tee /dev/tty  | docker cp alembic:$(cut -d' ' -f2) schema/alembic/versions/
# stop alembic container
docker rm -f alembic > /dev/null
rm "$tmpfile"
