#!/bin/bash
#
# Build & install mcpelauncher-thesonicmaster from latest sources.
# For more information about mcpelauncher-thesonicmaster, see
# https://mcpelauncher-thesonicmaster.sourceforge.io
#
# This script will create a portable AppImage executable.
#
# Copyright (C) 2021 The Sonic Master
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <https://www.gnu.org/licenses/>.
#
# Exit on error.
set -e
# Print status messages in colour and in bold.
status() {
  echo -e "\e[1m\e[32m$*\e[0m"
}
status2() {
  printf "\e[1m\e[32m$*\e[0m"
}
warn() {
  echo -e "\e[1m\e[33m$*\e[0m"
}
error() {
  echo -e "\e[1m\e[31m$*\e[0m" >&2
}
# Initial status message.
status "==> AppImage build script for mcpelauncher-thesonicmaster."
status "==> Copyright (c) 2021 The Sonic Master."
sleep 1
echo
# Display a warning if running as root, but don't stop the script.
if [ $EUID = 0 ]; then
  warn "==> WARNING: While no cats have been harmed, this script may contain"
  warn "==> bugs that could damage your system. Therefore, running as root is"
  warn "==> strongly discouraged. The Sonic Master assumes no responsiblity"
  warn "==> for any damage to your system as a result of usage of this script."
  sleep 3
  echo
  warn "==> Press CTRL+C to cancel, or the script will proceed in 10s..."
  sleep 10
  echo
fi
# Set architecture.
case $(uname -m) in
  x86_64) arch=x86_64 ;;
  i?86) arch=i386 ;;
esac
# Save the current directory so we know where to put the finished DEB package.
savedir="$(pwd)"
# Change to a clean build directory.
builddir=/tmp/build$(date "+%Y%m%d%H%M%S")
mkdir -p $builddir && cd $builddir
# Set package directory and app directory.
pkgdir=/tmp/appimage$(date "+%Y%m%d%H%M%S")
appdir=$pkgdir/AppDir
# Check and set version version
status2 "==> Checking version... "
ver="$(curl -Ls https://downloads.sourceforge.net/mcpelauncher-thesonicmaster/latest.version)"
status "$ver"
# Download latest source code.
status "==> Downloading source code..."
curl -LO https://downloads.sourceforge.net/mcpelauncher-thesonicmaster/sources/mcpelauncher-thesonicmaster-$ver.tar.xz
# Verify source sha256sum.
status2 "==> Verifying source against sha256sum... "
curl -Ls https://downloads.sourceforge.net/mcpelauncher-thesonicmaster/sources/mcpelauncher-thesonicmaster-$ver.tar.xz.sha256 | sha256sum -c > /dev/null
status "All Good!"
# Extract source tarball.
status "==> Unpacking source tarball, please be patient..."
tar -xJf mcpelauncher-thesonicmaster-$ver.tar.xz
# Remove tarball to free up space.
rm mcpelauncher-thesonicmaster-$ver.tar.xz
# Change to source directory.
cd mcpelauncher-thesonicmaster-$ver
# Specify cmake options for the build.
cmake_options="-DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -Wno-dev -G Ninja"
# Build MSA.
status "==> Building MSA (for Xbox Live)..."
cd msa
mkdir build && cd build
CC=clang CXX=clang++ CFLAGS='-O3' CXXFLAGS='-O3' cmake -DENABLE_MSA_QT_UI=ON $cmake_options ..
ninja
# Install MSA.
status "==> Installing MSA..."
DESTDIR=$appdir ninja install
cd ../..
# Build the game launcher.
status "==> Building the game launcher..."
cd mcpelauncher
wget https://gist.githubusercontent.com/kanafutile/d77b5b89ff2c2aa32c77fa57e12bfc1f/raw/e7a2e06ee7eb56ca9b5649a880e509051f63ea10/eglut_from_mesa_demos.patch
patch eglut/src/eglut.c eglut_from_mesa_demos.patch
mkdir build && cd build
CC=clang CXX=clang++ CFLAGS='-O3' CXXFLAGS='-O3' cmake -DMSA_DAEMON_PATH=. -DXAL_WEBVIEW_QT_PATH=. -DENABLE_QT_ERROR_UI=OFF -DJNI_USE_JNIVM=ON $cmake_options ..
ninja
# Install the game launcher.
status "==> Installing the game launcher..."
DESTDIR=$appdir ninja install
cd ../..
# Build the Qt GUI.
status "==> Building the Qt GUI..."
cd mcpelauncher-ui
mkdir build && cd build
CC=clang CXX=clang++ CFLAGS='-O3' CXXFLAGS='-O3' cmake -DGAME_LAUNCHER_PATH=. -DLAUNCHER_VERSION_CODE="APPIMAGE" $cmake_options ..
ninja
# Install the Qt GUI.
status "==> Installing the Qt GUI..."
DESTDIR=$appdir ninja install
cp ../mcpelauncher-ui-qt/Resources/proprietary/mcpelauncher-icon-512.png ../../../mcpelauncher-ui-qt.png
cp ../mcpelauncher-ui-qt/mcpelauncher-ui-qt.desktop ../../../mcpelauncher-ui-qt.desktop
# Strip unneeded debugging symbols to free up space.
status "==> Stripping executables..."
cd $appdir/usr/bin
strip --strip-all *
# Package AppImage
lddir=/tmp/ld$(date "+%Y%m%d%H%M%S")
mkdir -p $lddir && cd $lddir
status "==> Downloading linuxdeploy..."
if [ $arch = x86_64 ]; then
  curl -LO https://artifacts.assassinate-you.net/linuxdeploy/travis-456/linuxdeploy-x86_64.AppImage
  curl -LO https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage
elif [ $arch = i386 ]; then
  curl -LO https://artifacts.assassinate-you.net/linuxdeploy/travis-456/linuxdeploy-i386.AppImage
  curl -LO https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-i386.AppImage
else
  error "==> Invalid architecture; cannot download linuxdeploy. Exiting..."
  exit 1
fi
chmod +x linuxdeploy*-$arch.AppImage
# Extract linuxdeploy.
status "==> Extracting linuxdeploy..."
mkdir -p linuxdeploy && cd linuxdeploy
../linuxdeploy-$arch.AppImage --appimage-extract
cd ..
mkdir -p linuxdeploy-plugin-qt && cd linuxdeploy-plugin-qt
../linuxdeploy-plugin-qt-$arch.AppImage --appimage-extract
cd ..
# Run linuxdeploy.
status "==> Running linuxdeploy..."
linuxdeploy/squashfs-root/AppRun --appdir $appdir -i $builddir/mcpelauncher-ui-qt.png -d $builddir/mcpelauncher-ui-qt.desktop
export QML_SOURCES_PATHS=$builddir/mcpelauncher-thesonicmaster-$ver/mcpelauncher-ui/mcpelauncher-ui-qt/qml/:$builddir/mcpelauncher-thesonicmaster-$ver/mcpelauncher/mcpelauncher-webview
linuxdeploy-plugin-qt/squashfs-root/AppRun --appdir $appdir
status "==> Installing additional files..."
cp -r /usr/lib/$arch-linux-gnu/nss $appdir/usr/lib/
curl -Ls https://curl.se/ca/cacert.pem --output $appdir/usr/share/mcpelauncher/cacert.pem
# Write AppRun file.
cat > AppRun << "END"
#!/bin/bash
DIR="$( cd "$( dirname "\${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export XDG_DATA_DIRS=\${XDG_DATA_DIRS-"/usr/local/share:/usr/share"}
for i in \${XDG_DATA_DIRS//:/ }
do
    FMOD_RUNPATH=\${FMOD_RUNPATH+"\${FMOD_RUNPATH}:"}\$i/mcpelauncher/libs/native
done
export LD_LIBRARY_PATH=\${LD_LIBRARY_PATH+"\${LD_LIBRARY_PATH}:"}\$FMOD_RUNPATH:\$DIR/usr/share/mcpelauncher/libs/native:\$DIR/usr/lib:\$DIR/usr/lib32
export QT_QUICK_BACKEND=software
$DIR/usr/bin/msa-daemon&
MSADAEMON=\$!
$DIR/usr/bin/msa-ui-qt&
MSAUIQT=\$!
$DIR/usr/bin/mcpelauncher-ui-qt "\$@"
kill \$MSAUIQT
kill \$MSADAEMON
END
status "==> Building AppImage..."
export ARCH=$arch
export OUTPUT="mcpelauncher-thesonicmaster-$ver-$arch.AppImage"
ARCH=$arch linuxdeploy/squashfs-root/AppRun --appdir $appdir --output appimage
mv mcpelauncher-thesonicmaster-$ver-$arch.AppImage "$savedir"
status "==> Cleaning up..."
rm -rf $builddir $pkgdir $lddir
status "==> AppImage successfully created."
