# Stage 1: Base image with dependencies
FROM archlinux:base AS base

# Update and install dependencies in a single layer to reduce layers and use caching
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm --needed l-smash aom vapoursynth ffms2 libvpx mkvtoolnix-cli svt-av1 vmaf && \
    pacman -Scc --noconfirm

# Stage 2: Build image with additional dependencies
FROM base AS build-base

# Install build dependencies and clean up cache
RUN pacman -S --noconfirm --needed rust clang nasm git && \
    pacman -Scc --noconfirm

# Install cargo-chef for build preparation
RUN cargo install cargo-chef
WORKDIR /tmp/Av1an

# Stage 3: Planner stage
FROM build-base AS planner

COPY . .
RUN cargo chef prepare

# Stage 4: Build stage
FROM build-base AS build

# Copy recipe from planner stage and build using cargo-chef
COPY --from=planner /tmp/Av1an/recipe.json recipe.json
RUN cargo chef cook --release

# Compile rav1e from source and move it to the correct location
RUN git clone https://github.com/xiph/rav1e && \
    cd rav1e && \
    cargo build --release --jobs $(nproc) && \
    strip ./target/release/rav1e && \
    mv ./target/release/rav1e /usr/local/bin && \
    cd .. && rm -rf ./rav1e

# Build av1an from source
COPY . /tmp/Av1an
RUN cargo build --release --jobs $(nproc) && \
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
    x265 --version && \
    pacman -Scc --noconfirm

# Stage 5: Runtime image
FROM base AS runtime

# Set environment variable
ENV MPLCONFIGDIR="/home/app_user/"

# Copy the compiled binaries from build stage
COPY --from=build /usr/local/bin/rav1e /usr/local/bin/rav1e
COPY --from=build /usr/local/bin/av1an /usr/local/bin/av1an

# Create a non-root user to run the application
RUN useradd -ms /bin/bash app_user
USER app_user

# Set the working directory and expose the volume
VOLUME ["/videos"]
WORKDIR /videos

# Set the entry point for av1an
ENTRYPOINT [ "/usr/local/bin/av1an" ]
