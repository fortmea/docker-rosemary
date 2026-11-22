FROM --platform=linux/amd64 ubuntu:22.04
RUN apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    make bc bison flex libssl-dev libelf-dev python3 python-is-python3 cpio kmod git \
    binutils-aarch64-linux-gnu binutils-arm-linux-gnueabi perl xz-utils gzip ca-certificates curl >/dev/null
WORKDIR /host
ENTRYPOINT ["/host/build.sh"]
