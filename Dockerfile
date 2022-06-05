FROM cr.loongnix.cn/loongson/loongnix-server:8.3

ARG BUILDX_VERSION=v0.8.2

ENV BUILDX_VERSION=v0.8.2 \
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
    GOOS=linux

# loongarch64 rewrite go.sum
RUN set -ex; \
    cd /opt/buildx; \
    sed -i 's@h1:l9EaZDICImO1ngI+uTifW+ZYvvz7fKISBAKpg+MbWbY=@h1:u9vuu6qqG7nN9a735Noed0ahoUm30iipVRlhgh72N0M=@g' go.sum; \
    go mod download -x; \
    PKG=github.com/docker/buildx VERSION=$(git describe --match 'v[0-9]*' --dirty='' --always --tags) REVISION=$(git rev-parse HEAD); \
    echo "-X ${PKG}/version.Version=${VERSION} -X ${PKG}/version.Revision=${REVISION} -X ${PKG}/version.Package=${PKG}" | tee /tmp/.ldflags; \
    echo -n "${VERSION}" | tee /tmp/.version;

ENV GOPROXY=http://goproxy.loongnix.cn:3000

RUN set -ex; \
    cd /opt/buildx; \
    go get -u golang.org/x/sys; \
    go mod download golang.org/x/term; \
    go mod vendor; \
    rm -rf /opt/buildx/vendor;

# unix: add openat2 for linux, https://github.com/golang/sys/commit/eff7692f900947b7d782d16af70ca32cc40774f0
COPY golang.org/x/sys/unix/*.go $GOPATH/pkg/mod/golang.org/x/sys@v0.0.0-20220520151302-bc2c85ada10a/unix/
COPY golang.org/x/sys/unix/linux/types.go $GOPATH/pkg/mod/golang.org/x/sys@v0.0.0-20220520151302-bc2c85ada10a/unix/linux/

ENV CGO_ENABLED=0
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
