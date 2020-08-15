ARG DEBIAN_VERSION=buster-slim
FROM debian:${DEBIAN_VERSION}

RUN apt-get update && apt-get -y install curl xz-utils wget gpg build-essential apt-transport-https apt-utils sudo git gnupg-agent software-properties-common && \
    rm -rf /var/cache/apt/* && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/* && \
    mkdir -p /usr/share/man/man1/ && \
    mkdir -p /usr/local/theia

# Install Python 3
RUN apt-get update && \
    apt-get install -y python2 python3-dev python3-pip && \
    rm -rf /var/cache/apt/* && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/* && \
    pip3 install --upgrade pip --user && \
    pip3 install --upgrade pylint python-language-server flake8 autopep8;

RUN set -ex && \
    for key in \
    4ED778F539E3634C779C87C6D7062848A1AB005C \
    B9E2F5981AA6E0CD28160D9FF13993A75599653C \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    B9AE9905FFD7803F25714661B63B535A4C206CA9 \
    77984A986EBC2AA786BC0F66B01FBB92821C587A \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    FD3A5288F042B6850C66B31F09FE44734EB7990E \
    8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
    ; do \
    gpg --batch --keyserver ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --batch --keyserver pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --batch --keyserver pgp.mit.edu --recv-keys "$key" || \
    gpg --batch --keyserver keyserver.pgp.com --recv-keys "$key" || \
    gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$key" ; \
    done

# Install Node
ARG NODE_VER=10.15.3
RUN ARCH= && dpkgArch="$(dpkg --print-architecture)" && \
    case "${dpkgArch##*-}" in \
    amd64) ARCH='x64';; \
    ppc64el) ARCH='ppc64le';; \
    s390x) ARCH='s390x';; \
    arm64) ARCH='arm64';; \
    armhf) ARCH='armv7l';; \
    i386) ARCH='x86';; \
    *) echo "unsupported architecture"; exit 1 ;; \
    esac && \
    curl -SLO "https://nodejs.org/dist/v$NODE_VER/node-v$NODE_VER-linux-$ARCH.tar.xz" && \
    curl -SLO --compressed "https://nodejs.org/dist/v$NODE_VER/SHASUMS256.txt.asc" && \
    gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc && \
    grep " node-v$NODE_VER-linux-$ARCH.tar.xz\$" SHASUMS256.txt | sha256sum -c - && \
    tar -xJf "node-v$NODE_VER-linux-$ARCH.tar.xz" -C /usr/local --strip-components=1 --no-same-owner && \
    rm "node-v$NODE_VER-linux-$ARCH.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt && \
    ln -s /usr/local/bin/node /usr/local/bin/nodejs

# Install yarn
ARG YARN_VER=1.22.4
RUN set -ex \
    && for key in \
    6A010C5166006599AA17F08146C2130DFD2497F5 \
    ; do \
    gpg --batch --keyserver ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --batch --keyserver pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --batch --keyserver pgp.mit.edu --recv-keys "$key" || \
    gpg --batch --keyserver keyserver.pgp.com --recv-keys "$key" || \
    gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$key" ; \
    done && \
    curl -fSLO --compressed "https://yarnpkg.com/downloads/$YARN_VER/yarn-v$YARN_VER.tar.gz" && \
    curl -fSLO --compressed "https://yarnpkg.com/downloads/$YARN_VER/yarn-v$YARN_VER.tar.gz.asc" && \
    gpg --batch --verify yarn-v$YARN_VER.tar.gz.asc yarn-v$YARN_VER.tar.gz && \
    mkdir -p /opt/yarn && \
    tar -xzf yarn-v$YARN_VER.tar.gz -C /opt/yarn --strip-components=1 && \
    ln -s /opt/yarn/bin/yarn /usr/local/bin/yarn && \
    ln -s /opt/yarn/bin/yarn /usr/local/bin/yarnpkg && \
    rm yarn-v$YARN_VER.tar.gz.asc yarn-v$YARN_VER.tar.gz

WORKDIR /usr/local/theia

ARG version=latest
ADD files/package.json ./package.json
RUN yarn --cache-folder ./ycache && rm -rf ./ycache && \
    NODE_OPTIONS="--max_old_space_size=4096" yarn theia build ; \
    yarn theia download:plugins && \
    yarn autoclean


ENV SHELL=/bin/bash \
    THEIA_DEFAULT_PLUGINS=local-dir:/usr/local/theia/plugins

RUN mkdir -p /etc/skel/.theia /etc/skel/workspace /etc/skel/.ssh /workspace/.cache
COPY files/init.sh /usr/local/bin/init.sh
COPY files/settings.json /etc/skel/.theia
COPY files/ssh/config /etc/skel/.ssh/

RUN chmod +x /usr/local/bin/init.sh && chown -R 1001:1001 /workspace

RUN adduser --gecos '' --uid 1001 --shell /bin/bash --disabled-password coder && \ 
    echo "%coder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

VOLUME /home/coder
  
EXPOSE 3000
ENTRYPOINT ["/usr/local/bin/init.sh"]
