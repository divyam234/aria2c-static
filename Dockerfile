FROM alpine:latest AS builder

RUN apk add --no-cache \
    build-base \
    autoconf \
    automake \
    libtool \
    pkgconf \
    git \
    curl \
    patch \
    ca-certificates \
    linux-headers \
    gettext \
    gettext-dev \
    zlib-static \
    zlib-dev \
    expat-static \
    expat-dev \
    sqlite-static \
    sqlite-dev \
    gmp-static \
    gmp-dev \
    libressl-dev \
    libressl-static \
    c-ares-dev

ENV CFLAGS="-O3 -g0 -static"
ENV CXXFLAGS="-O3 -g0 -static"
ENV LDFLAGS="-static -latomic"
ENV PKG_CONFIG="pkg-config --static"

WORKDIR /build

RUN curl -L -O https://libssh2.org/download/libssh2-1.11.1.tar.bz2 && \
    tar xf libssh2-1.11.1.tar.bz2 && \
    cd libssh2-1.11.1 && \
    ./configure --enable-static --disable-shared \
    --with-openssl &&\
    make -j$(nproc) && make install

RUN git clone https://github.com/aria2/aria2.git /aria2
WORKDIR /aria2

RUN git fetch --tags && \
    latestTag=$(git describe --tags `git rev-list --tags --max-count=1`) && \
    git checkout $latestTag

COPY patches/ /patches/
RUN for patch in /patches/*.patch; do \
    patch -p1 < "$patch"; \
    done

RUN autoreconf -i && \
    ./configure --enable-static --disable-shared \
    --without-gnutls \
    --with-openssl \
    --with-libssh2 \
    --with-sqlite3 \
    --with-libz \
    --with-libexpat \
    --with-libcares \
    --with-libgmp \
    --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt \
    ARIA2_STATIC=yes

RUN make -j$(nproc)
RUN strip /aria2/src/aria2c

FROM scratch
COPY --from=builder /aria2/src/aria2c /aria2c

ENTRYPOINT [ "/aria2c" ]
