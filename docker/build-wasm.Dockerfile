# Single-file build using a local rdkit source tree.
# Combines Dockerfile_1_deps + Dockerfile_2_rdkit_copy_from_local +
# Dockerfile_3_rdkit_build + Dockerfile_4_rdkit_export into one file
# so no named intermediate images are required.
#
# Usage (run from the rdkit repo root, i.e. three levels above this file):
#
#   DOCKER_BUILDKIT=1 docker build \
#     -f Code/MinimalLib/docker/Dockerfile_local_build \
#     --build-arg "EXCEPTION_HANDLING=-fwasm-exceptions" \
#     -o Code/MinimalLib/dist \
#     .

ARG EMSDK_VERSION="latest"
ARG EXCEPTION_HANDLING="-fwasm-exceptions"
ARG BOOST_MAJOR_VERSION="1"
ARG BOOST_MINOR_VERSION="87"
ARG BOOST_PATCH_VERSION="0"
ARG FREETYPE_VERSION="2.13.3"
ARG ZLIB_VERSION="1.3.2"

# ---------------------------------------------------------------------------
# Stage 1: build dependencies (emsdk, Boost, FreeType, zlib)
# ---------------------------------------------------------------------------
FROM debian:bookworm AS deps-stage
ARG EMSDK_VERSION
ARG EXCEPTION_HANDLING
ARG BOOST_MAJOR_VERSION
ARG BOOST_MINOR_VERSION
ARG BOOST_PATCH_VERSION
ARG FREETYPE_VERSION
ARG ZLIB_VERSION

LABEL maintainer="Greg Landrum <greg.landrum@t5informatics.com>"

SHELL ["/bin/bash", "-c", "-l"]
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get upgrade -y && apt install -y \
  curl \
  wget \
  cmake \
  python3 \
  g++ \
  libeigen3-dev \
  git \
  xz-utils \
  nodejs

ENV LANG C

WORKDIR /opt
RUN git clone https://github.com/emscripten-core/emsdk.git

WORKDIR /src
ARG BOOST_DOT_VERSION="${BOOST_MAJOR_VERSION}.${BOOST_MINOR_VERSION}.${BOOST_PATCH_VERSION}"
ARG BOOST_UNDERSCORE_VERSION="${BOOST_MAJOR_VERSION}_${BOOST_MINOR_VERSION}_${BOOST_PATCH_VERSION}"
RUN wget -q https://archives.boost.io/release/${BOOST_DOT_VERSION}/source/boost_${BOOST_UNDERSCORE_VERSION}.tar.gz && \
  tar xzf boost_${BOOST_UNDERSCORE_VERSION}.tar.gz
WORKDIR /src/boost_${BOOST_UNDERSCORE_VERSION}
RUN ./bootstrap.sh --prefix=/opt/boost --with-libraries=system && \
  ./b2 install

WORKDIR /opt/emsdk
RUN ./emsdk install ${EMSDK_VERSION} && \
  ./emsdk activate ${EMSDK_VERSION}

RUN echo "source /opt/emsdk/emsdk_env.sh > /dev/null 2>&1" >> ~/.bashrc

WORKDIR /src
RUN wget -q https://download.savannah.gnu.org/releases/freetype/freetype-${FREETYPE_VERSION}.tar.gz && \
  tar xzf freetype-${FREETYPE_VERSION}.tar.gz
WORKDIR /src/freetype-${FREETYPE_VERSION}
RUN mkdir build
WORKDIR /src/freetype-${FREETYPE_VERSION}/build
RUN emcmake cmake -DCMAKE_BUILD_TYPE=Release \
  -DFT_DISABLE_ZLIB=TRUE -DFT_DISABLE_BZIP2=TRUE -DFT_DISABLE_PNG=TRUE \
  -DFT_DISABLE_HARFBUZZ=TRUE -DFT_DISABLE_BROTLI=TRUE \
  -DCMAKE_C_FLAGS="${EXCEPTION_HANDLING}" -DCMAKE_EXE_LINKER_FLAGS="${EXCEPTION_HANDLING}" \
  -DCMAKE_INSTALL_PREFIX=/opt/freetype ..
RUN make -j2 && make -j2 install

WORKDIR /src
RUN wget -q https://github.com/madler/zlib/releases/download/v${ZLIB_VERSION}/zlib-${ZLIB_VERSION}.tar.gz && \
  tar xzf zlib-${ZLIB_VERSION}.tar.gz
WORKDIR /src/zlib-${ZLIB_VERSION}
RUN mkdir build
WORKDIR /src/zlib-${ZLIB_VERSION}/build
RUN emcmake cmake -DCMAKE_BUILD_TYPE=Release -DZLIB_BUILD_EXAMPLES=OFF \
  -DCMAKE_C_FLAGS="${EXCEPTION_HANDLING}" -DCMAKE_EXE_LINKER_FLAGS="${EXCEPTION_HANDLING}" \
  -DCMAKE_INSTALL_PREFIX=/opt/zlib ..
RUN make && make install

RUN echo "export BOOST_DOT_VERSION=${BOOST_DOT_VERSION}" >> ~/.bashrc
RUN echo "export BOOST_UNDERSCORE_VERSION=${BOOST_UNDERSCORE_VERSION}" >> ~/.bashrc

# ---------------------------------------------------------------------------
# Stage 2: copy local rdkit source into the image
# (build context must be the rdkit repo root)
# ---------------------------------------------------------------------------
FROM deps-stage AS src-stage

WORKDIR /
COPY Code /src/rdkit/Code
COPY External /src/rdkit/External
COPY CMakeLists.txt license.txt *.in *.md *.cmake /src/rdkit/

# ---------------------------------------------------------------------------
# Stage 3: configure, patch, build, test
# ---------------------------------------------------------------------------
FROM src-stage AS build-stage
ARG EXCEPTION_HANDLING
ARG BOOST_MAJOR_VERSION
ARG BOOST_MINOR_VERSION
ARG BOOST_PATCH_VERSION

SHELL ["/bin/bash", "-c", "-l"]

WORKDIR /src
ENV RDBASE=/src/rdkit
RUN mkdir build
WORKDIR $RDBASE/build

ARG BOOST_DOT_VERSION="${BOOST_MAJOR_VERSION}.${BOOST_MINOR_VERSION}.${BOOST_PATCH_VERSION}"

RUN emcmake cmake \
  -DRDK_BUILD_FREETYPE_SUPPORT=ON \
  -DRDK_BUILD_MINIMAL_LIB=ON \
  -DRDK_BUILD_PYTHON_WRAPPERS=OFF \
  -DRDK_BUILD_CPP_TESTS=OFF \
  -DRDK_BUILD_INCHI_SUPPORT=ON \
  -DRDK_USE_BOOST_SERIALIZATION=OFF \
  -DRDK_OPTIMIZE_POPCNT=OFF \
  -DRDK_BUILD_THREADSAFE_SSS=OFF \
  -DRDK_BUILD_DESCRIPTORS3D=OFF \
  -DRDK_TEST_MULTITHREADED=OFF \
  -DRDK_BUILD_CHEMDRAW_SUPPORT=OFF \
  -DRDK_BUILD_MAEPARSER_SUPPORT=OFF \
  -DRDK_BUILD_COORDGEN_SUPPORT=ON \
  -DRDK_BUILD_MINIMAL_LIB_MCS=ON \
  -DRDK_BUILD_MINIMAL_LIB_MOLZIP=ON \
  -DRDK_BUILD_MINIMAL_LIB_MMPA=ON \
  -DRDK_BUILD_MINIMAL_LIB_RXN=ON \
  -DBoost_DIR=/opt/boost/lib/cmake/Boost-${BOOST_DOT_VERSION} \
  -Dboost_headers_DIR=/opt/boost/lib/cmake/boost_headers-${BOOST_DOT_VERSION} \
  -DRDK_BUILD_SLN_SUPPORT=OFF \
  -DRDK_USE_BOOST_IOSTREAMS=OFF \
  -DFREETYPE_INCLUDE_DIRS=/opt/freetype/include/freetype2 \
  -DFREETYPE_LIBRARY=/opt/freetype/lib/libfreetype.a \
  -DZLIB_INCLUDE_DIR=/opt/zlib/include \
  -DZLIB_LIBRARY=/opt/zlib/lib/libz.a \
  -DCMAKE_CXX_FLAGS="${EXCEPTION_HANDLING} -O3 -DNDEBUG" \
  -DCMAKE_C_FLAGS="${EXCEPTION_HANDLING} -O3 -DNDEBUG -DCOMPILE_ANSI_ONLY" \
  "-DCMAKE_EXE_LINKER_FLAGS=${EXCEPTION_HANDLING} -s STACK_OVERFLOW_CHECK=1 -s USE_PTHREADS=0 -s ALLOW_MEMORY_GROWTH=1 -s MAXIMUM_MEMORY=4GB -s MODULARIZE=1 -s EXPORT_NAME='initRDKitModule' -s USE_ZLIB=0" \
  ..

# Patch to make InChI code work with emscripten
RUN cp /src/rdkit/External/INCHI-API/src/INCHI_BASE/src/util.c \
       /src/rdkit/External/INCHI-API/src/INCHI_BASE/src/util.c.bak && \
  sed 's/&& defined(__APPLE__)//' \
      /src/rdkit/External/INCHI-API/src/INCHI_BASE/src/util.c.bak \
    > /src/rdkit/External/INCHI-API/src/INCHI_BASE/src/util.c

# Patch RapidJSON document.h compilation error (only if the file exists;
# in some rdkit versions rapidjson is fetched later during make)
RUN f=/src/rdkit/External/rapidjson-1.1.0/include/rapidjson/document.h; \
  if [ -f "$f" ]; then \
    sed -i 's|^\( *\)\(GenericStringRef\& operator=(const GenericStringRef\& rhs) { s = rhs.s; length = rhs.length; } *\)$|\1//\2|' "$f"; \
  else \
    echo "rapidjson document.h not found yet, skipping pre-patch (will be patched if needed at build time)"; \
  fi

# Build
RUN make -j2 RDKit_minimal && \
  cp Code/MinimalLib/RDKit_minimal.* ../Code/MinimalLib/demo/

# Run tests
WORKDIR /src/rdkit/Code/MinimalLib/tests
RUN /opt/emsdk/node/*/bin/node tests.js

# ---------------------------------------------------------------------------
# Stage 4: export artifacts only (requires BuildKit --output)
# ---------------------------------------------------------------------------
FROM scratch AS export-stage
COPY --from=build-stage /src/rdkit/Code/MinimalLib/demo /
COPY --from=build-stage /src/rdkit/Code/MinimalLib/docs /
