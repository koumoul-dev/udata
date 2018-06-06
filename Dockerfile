##########################################
# Dockerfile for udata
# Use multistage build to separate a builder image with webpack, etc.
# from a lighter definitive runner image
##########################################

FROM udata/system AS builder

WORKDIR /udata

# Install nodejs and npm dependencies for webpack build
RUN apt-get update && apt-get install -y gnupg
RUN curl -sL https://deb.nodesource.com/setup_8.x | bash -
RUN apt-get install -y nodejs
COPY package.json .
RUN npm install

# Install pip dependencies
COPY requirements ./requirements
RUN pip install -r ./requirements/develop.pip

# Install udata itself from sources in context
COPY udata ./udata
COPY js ./js
COPY less ./less
COPY *.py *.cfg *.js *.yml *.md ./

# Build
RUN inv assets-build
RUN inv widgets-build
RUN inv i18nc

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

# Install udata dependencies
COPY requirements /tmp/requirements/
RUN pip install -r /tmp/requirements/install.pip

# Install udata from the directory built in the builder stage
COPY --from=builder /udata /udata
WORKDIR /udata
RUN pip install -e .

# Install dependencies for running udata and some known plugins
COPY docker/requirements.pip /tmp/requirements/docker.pip
RUN pip install -r /tmp/requirements/docker.pip

RUN mkdir -p /udata/fs /src

COPY docker/udata.cfg docker/entrypoint.sh /udata/
COPY docker/uwsgi/*.ini /udata/uwsgi/

VOLUME /udata/fs

ENV UDATA_SETTINGS /udata/udata.cfg

EXPOSE 7000 7001

HEALTHCHECK --interval=5s --timeout=3s CMD curl --fail http://localhost:7000/ || exit 1

ENTRYPOINT ["/udata/entrypoint.sh"]
CMD ["uwsgi"]
