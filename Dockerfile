# Stage 1: Base image with dependencies
FROM archlinux:base-devel AS base

RUN pacman -Syu --noconfirm

# Install dependencies needed by all steps including runtime step, but don't install x264 and x265
RUN pacman -S --noconfirm --needed l-smash vapoursynth ffms2 mkvtoolnix-cli vmaf libnuma

# Stage 2: Build image with additional dependencies
FROM base AS build-base

# Install dependencies needed by build steps
RUN pacman -S --noconfirm --needed rust clang nasm git

RUN cargo install cargo-chef
WORKDIR /tmp/Av1an

# Stage 3: Planner stage
FROM build-base AS planner

COPY . .
RUN cargo chef prepare

# Stage 4: Build stage
FROM build-base AS build

COPY --from=planner /tmp/Av1an/recipe.json recipe.json
RUN cargo chef cook --release

# Compile rav1e from git, as archlinux is still on rav1e 0.4
RUN git clone https://github.com/xiph/rav1e && \
    cd rav1e && \
    cargo build --release && \
    strip ./target/release/rav1e && \
    mv ./target/release/rav1e /usr/local/bin && \
    cd .. && rm -rf ./rav1e

# Build av1an
COPY . /tmp/Av1an

RUN cargo build --release && \
    mv ./target/release/av1an /usr/local/bin && \
    cd .. && rm -rf ./Av1an

# FFmpeg setup: Uninstall old versions and install new versions in one step to reduce layers
RUN pacman -Qi x264 && pacman -Rns --noconfirm x264 || echo "x264 not installed" && \
    pacman -Qi x265 && pacman -Rns --noconfirm x265 || echo "x265 not installed" && \
    curl -L https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linux64-gpl.tar.xz -o ffmpeg.tar.xz && \
    tar -xvf ffmpeg.tar.xz && \
    mv -v ffmpeg-master-latest-linux64-gpl/bin/* /usr/bin && \
    chmod 777 /usr/bin/ffmpeg && \
    curl -L https://onedrive-cf-index-ng-76f.pages.dev/api/raw?path=/x265 -o /usr/bin/x265 && \
    chmod 777 /usr/bin/x265 && \
    curl -L https://onedrive-cf-index-ng-76f.pages.dev/api/raw?path=/x264 -o /usr/bin/x264 && \
    chmod 777 /usr/bin/x264 && \
    x264 --version && \
    x265 --version
    

# Stage 5: Runtime image
FROM base AS runtime

ENV MPLCONFIGDIR="/home/app_user/"

COPY --from=build /usr/local/bin/rav1e /usr/local/bin/rav1e
COPY --from=build /usr/local/bin/av1an /usr/local/bin/av1an

# Create user
RUN useradd -ms /bin/bash app_user
USER app_user

VOLUME ["/videos"]
WORKDIR /videos

ENTRYPOINT [ "/usr/local/bin/av1an" ]
