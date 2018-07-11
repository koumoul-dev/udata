##########################################
# Dockerfile for udata
# Use multistage build to separate a builder image with webpack, etc.
# from a lighter definitive runner image
##########################################

FROM udata/system AS builder

WORKDIR /udata

RUN apt-get update && apt-get install -y gnupg gcc

# Install nodejs and npm dependencies for webpack build
RUN curl -sL https://deb.nodesource.com/setup_8.x | bash -
RUN apt-get install -y nodejs
COPY package.json .
RUN npm install

# Install pip dependencies
RUN pip install Cython wheel virtualenv
RUN virtualenv venv
RUN /udata/venv/bin/pip install --upgrade pip
COPY requirements ./requirements
RUN /udata/venv/bin/pip install -r ./requirements/develop.pip

# Install udata itself from sources in context
COPY udata ./udata
COPY js ./js
COPY less ./less
COPY *.py *.cfg *.js *.yml *.md LICENSE MANIFEST.in ./

# Build
RUN /udata/venv/bin/python setup.py compile_catalog
RUN npm run assets:build
RUN npm run widgets:build
RUN npm run oembed:build

RUN /udata/venv/bin/pip install .

# Second part is mostly a clone of the Dockerfile in the separate project docker-udata
FROM udata/system

MAINTAINER Open Data Team

# Install some production system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # uWSGI rooting features
    libpcre3-dev \
    # Clean up
    && apt-get autoremove\
    && apt-get clean\
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /udata

# Fetch full python env from builder image
RUN pip install Cython wheel virtualenv
COPY --from=builder /udata/venv /udata/venv
# Install dependencies for running udata and some known plugins
COPY docker/requirements.pip ./requirements/docker.pip
RUN /udata/venv/bin/pip install -r ./requirements/docker.pip

RUN mkdir -p /udata/fs /src

COPY docker/udata.cfg docker/entrypoint.sh /udata/
COPY docker/uwsgi/*.ini /udata/uwsgi/

VOLUME /udata/fs

ENV UDATA_SETTINGS /udata/udata.cfg

EXPOSE 7000 7001

# TODO: a better health check ?
# Calling localhost fails with a 404 when SERVER_NAME is defined in the config,
# and defining SERVER_NAME is required to be able to use 'udata search index'
# HEALTHCHECK --interval=5s --timeout=3s CMD curl --fail http://localhost:7000/ || exit 1

ENTRYPOINT ["/udata/entrypoint.sh"]
CMD ["uwsgi"]
