FROM cr.loongnix.cn/loongson/loongnix-server:8.3

ARG BUILDX_VERSION=v0.9.0

ENV BUILDX_VERSION=${BUILDX_VERSION} \
    GOPATH=/go \
    PATH=$GOPATH/bin:$PATH

RUN set -ex; \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime; \
    yum -y install loongnix-release-epel; \
    yum -y install golang-1.18 git file; \
    mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"; \
    yum clean all; \
    rm -rf /var/cache/yum/*;

RUN set -ex; \
    git clone -b ${BUILDX_VERSION} https://github.com/docker/buildx /opt/buildx; \
    rm -rf /opt/buildx/vendor;

WORKDIR /opt/buildx

ENV GOPROXY=https://goproxy.io \
    GOSUMDB=off \
    GO111MODULE=on \
    GOOS=linux \
    CGO_ENABLED=0

RUN set -ex; \
    cd /opt/buildx; \
    go mod download -x; \
    PKG=github.com/docker/buildx VERSION=$(git describe --match 'v[0-9]*' --dirty='' --always --tags) REVISION=$(git rev-parse HEAD); \
    echo "-X ${PKG}/version.Version=${VERSION} -X ${PKG}/version.Revision=${REVISION} -X ${PKG}/version.Package=${PKG}" | tee /tmp/.ldflags; \
    echo -n "${VERSION}" | tee /tmp/.version;

ARG LDFLAGS="-w -s"

RUN set -ex; \
    cd /opt/buildx; \
    mkdir /opt/buildx/dist; \
    go build -ldflags "$(cat /tmp/.ldflags) ${LDFLAGS}" -o /opt/buildx/dist/buildx ./cmd/buildx; \
    cd /opt/buildx/dist; \
    mv buildx buildx-${BUILDX_VERSION}-linux-$(uname -m); \
    echo "$(sha256sum buildx-${BUILDX_VERSION}-linux-$(uname -m) | awk '{print $1}') buildx-${BUILDX_VERSION}-linux-$(uname -m)" > "checksums.txt";

VOLUME /dist

CMD cp -rf dist/* /dist/
