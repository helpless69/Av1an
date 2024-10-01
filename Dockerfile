# syntax=docker/dockerfile:1-labs
FROM --platform=$BUILDPLATFORM fr3akyphantom/vapoursynth-av1an-base:latest

# Update System and Install Packages
RUN <<-'EOL'
    echo -e "Updating system and installing packages..."

    # Update the system
    ( sudo pacman -Syu --noconfirm 2>/dev/null ) || ( sudo pacman -Syu --noconfirm 2>/dev/null || true )
    ( sudo rm -rvf /var/cache/pacman/pkg/*.pkg.tar.zst* 2>/dev/null || true )
    set -ex

    # Update PATH
    export PATH="/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/bin"
    
    # List Pre-Installed Packages
    echo -e "[+] List of PreInstalled Packages:"
    echo -e "$(sudo pacman -Q | awk '{print $1}' | sed -z 's/\n/ /g;s/\s$/\n/g')" 2>/dev/null

    # Install basic tools
    sudo pacman -S --noconfirm --needed git unzip

    echo -e "[+] List of Packages Before Actual Operation:"
    echo -e "$(sudo pacman -Q | awk '{print $1}' | sed -z 's/\n/ /g;s/\s$/\n/g')" 2>/dev/null

    # Setup PARU options
    export PARU_OPTS="--skipreview --noprovides --useask --combinedupgrade --noprovides --batchinstall --noinstalldebug --removemake --cleanafter --nokeepsrc"
    
    echo -e "[+] Build Tools PreInstallation"
    paru -S --noconfirm --needed ${PARU_OPTS} cmake ninja clang nasm yasm meson compiler-rt jq rust cargo-c libgit2 zip p7zip python-pip

    # Clone package builds
    mkdir -p /home/app/.cache/paru/clone
    git clone -q --filter=blob:none https://github.com/rokibhasansagar/Arch_PKGBUILDs.git /home/app/.cache/paru/pkgbuilds/
    rm -rf /home/app/.cache/paru/pkgbuilds/.git

    # Custom package build and installation functions
    _custPKGBuilder() {
      for pkg in "${pkgs[@]}"; do
        echo -e "[+] ${pkg} Build+Installation with makepkg"
        cd /home/app/.cache/paru/pkgbuilds/${pkg}/
        ( paru -Ui --noconfirm --needed ${PARU_OPTS} --mflags="--force" --rebuild )
      done
    }
    
    _uninstPKG() {
      for pkg in "${unpkgs[@]}"; do
        ( sudo pacman -Rdd ${pkg} --noconfirm 2>/dev/null ) || true
      done
    }

    # Package Installation
    echo -e "[+] vapoursynth-git, ffmpeg and other tools Installation with pacman"
    export unpkgs=(zimg) && _uninstPKG
    export pkgs=({zimg,libdovi,libhdr10plus-rs}-git) && _custPKGBuilder
    paru -S --noconfirm --needed ${PARU_OPTS} ffmpeg ffms2 mkvtoolnix-cli numactl

    # Additional package handling
    export unpkgs=(libjxl) && _uninstPKG
    export pkgs=(libjxl-metrics-git) && _custPKGBuilder
    export unpkgs=(vapoursynth aom) && _uninstPKG
    export pkgs=({aom-psy101,vapoursynth,foosynth-plugin-lsmashsource}-git) && _custPKGBuilder

    libtool --finish /usr/lib &>/dev/null
    libtool --finish /usr/lib/python3.12/site-packages &>/dev/null
    sudo ldconfig 2>/dev/null

    echo -e "[-] Removing x265, svt-av1 to install latest version"
    export unpkgs=(x265 svt-av1) && _uninstPKG
    sudo ldconfig 2>/dev/null
    export pkgs=({x265,svt-av1-psy}-git) && _custPKGBuilder

    echo -e "[+] List of All Packages After Base Installation:"
    echo -e "$(sudo pacman -Q | awk '{print $1}' | sed -z 's/\n/ /g;s/\s$/\n/g')" 2>/dev/null

    echo -e "[>] PostPlugs PacCache Investigation"
    sudo du -sh /var/cache/pacman/pkg /home/app/.cache/paru/*
    ls -lAog /var/cache/pacman/pkg/*.pkg.tar.zst 2>/dev/null

    echo -e "[+] Plugins Installation Block Starts Here"
    # Install necessary plugins
    # llvm(17)-libs from Arch for vsakarin is needed now, Arch llvm-libs is now 18

    # Install necessary plugins
    export pkgs=(vapoursynth-plugin-{vsakarin,adjust,adaptivegrain}-git) && _custPKGBuilder
    export pkgs=({vapoursynth-plugin-,}waifu2x-ncnn-vulkan-git) && _custPKGBuilder

    # Continue with installation of various tools
    cd /tmp && paru -S --noconfirm --needed ${PARU_OPTS} onetbb vapoursynth-tools-getnative-git vapoursynth-plugin-{bestsource,bm3dcuda-cpu,eedi3m,havsfunc,imwri,kagefunc,knlmeanscl,muvsfunc,mvtools_sf,neo_f3kdb,neo_fft3dfilter,nlm,retinex,soifunc,ttempsmooth,vsdeband,vsdehalo,vsmasktools,vspyplugin,vstools,d2vsource,vssource,znedi3,resize2}-git vapoursynth-plugin-dgdecodenv-bin

    libtool --finish /usr/lib/vapoursynth &>/dev/null
    sudo ldconfig 2>/dev/null

    export pkgs=(zig-nightly-bin vapoursynth-plugin-{bmdegrain,wnnm,julek,vszip}-git av1an-git) && _custPKGBuilder
    libtool --finish /usr/lib/vapoursynth &>/dev/null
    sudo ldconfig 2>/dev/null

    export XDG_RUNTIME_DIR=/run/user/$UID
    echo -e "[i] Encoder and Av1an Investigation"
    
    # Verify installation of key tools
    ( ffmpeg -hide_banner -version || true )
    ( x265 -V 2>&1 || true )
    ( aomenc --help | grep "AOMedia Project AV1 Encoder" || true )
    ( vspipe --version || true )
    ( rav1e --version || true )
    ( av1an --version || true )
    ( SvtAv1EncApp --version || true )

    echo -e "[>] PostPlugs PacCache Investigation"
    set +ex
    echo -e "[>] Home directory Investigation"
    sudo du -sh ~/\.[a-z]* 2>/dev/null

    echo -e "[<] Cleanup"
    find "$(python -c "import os;print(os.path.dirname(os.__file__))")" -depth -type d -name __pycache__ -exec sudo rm -rf '{}' + 2>/dev/null
    sudo pacman -Rdd cmake ninja clang nasm yasm meson rust cargo-c zig-nightly-bin --noconfirm 2>/dev/null || true
    sudo rm -rf /tmp/* /var/cache/pacman/pkg/* /home/app/.cache/zig/* /home/app/.cache/yay/* /home/app/.cache/paru/{clone,pkgbuilds}/* /home/app/.cargo/* 2>/dev/null

    echo -e "[+] List of All Packages At The End Of All Process:"
    echo -e "$(sudo pacman -Q | awk '{print $1}' | sed -z 's/\n/ /g;s/\s$/\n/g')" 2>/dev/null
EOL

VOLUME ["/videos"]
WORKDIR /videos

ENTRYPOINT [ "/usr/local/bin/av1an" ]

