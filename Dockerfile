# Stage 1: Base image with dependencies
FROM archlinux:base-devel AS base

RUN pacman -Syu --noconfirm

# Install dependancies needed by all steps including runtime step
RUN pacman -S --noconfirm --needed l-smash vapoursynth ffms2 mkvtoolnix-cli vmaf


# Stage 2: Build image with additional dependencies
FROM base AS build-base

# Install dependancies needed by build steps
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

# Build av1an
COPY . /tmp/Av1an

RUN cargo build --release && \
    mv ./target/release/av1an /usr/local/bin && \
    cd .. && rm -rf ./Av1an

# FFmpeg setup
RUN curl -L https://onedrive-cf-index-ng-76f.pages.dev/api/raw?path=/x265 -o x265 && \
    mv -v x265 /usr/local/bin && \
    chmod 777 /usr/local/bin/x265


# Stage 5: Runtime image
FROM base AS runtime

ENV MPLCONFIGDIR="/home/app_user/"

COPY --from=build /usr/local/bin/av1an /usr/local/bin/av1an

# Create user
RUN useradd -ms /bin/bash app_user
USER app_user

VOLUME ["/videos"]
WORKDIR /videos

ENTRYPOINT [ "/usr/local/bin/av1an" ]
