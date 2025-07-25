#!/bin/bash

function prerequisite(){
#必要ライブラリ
pacman "${PACMAN_INSTALL_OPTS[@]}" \
${MINGW_PACKAGE_PREFIX}-SDL2 \
${MINGW_PACKAGE_PREFIX}-brotli \
${MINGW_PACKAGE_PREFIX}-vulkan-loader \
${MINGW_PACKAGE_PREFIX}-cc \
${MINGW_PACKAGE_PREFIX}-cmake \
${MINGW_PACKAGE_PREFIX}-ninja \
${MINGW_PACKAGE_PREFIX}-clang \
${MINGW_PACKAGE_PREFIX}-clang-tools-extra \
${MINGW_PACKAGE_PREFIX}-llvm \
${MINGW_PACKAGE_PREFIX}-pkgconf \
${MINGW_PACKAGE_PREFIX}-python \
${MINGW_PACKAGE_PREFIX}-xmlstarlet \
${MINGW_PACKAGE_PREFIX}-vulkan-headers \
${MINGW_PACKAGE_PREFIX}-dbus \
${MINGW_PACKAGE_PREFIX}-brotli \
${MINGW_PACKAGE_PREFIX}-freetype \
${MINGW_PACKAGE_PREFIX}-libjpeg-turbo \
${MINGW_PACKAGE_PREFIX}-libpng \
${MINGW_PACKAGE_PREFIX}-libtiff \
${MINGW_PACKAGE_PREFIX}-libwebp \
${MINGW_PACKAGE_PREFIX}-openssl \
${MINGW_PACKAGE_PREFIX}-pcre2 \
${MINGW_PACKAGE_PREFIX}-zlib \
${MINGW_PACKAGE_PREFIX}-zstd \
2> /dev/null

exitOnError

mkdir -p $PREFIX/bin 2> /dev/null
mkdir -p $QT6_STATIC_PREFIX/bin 2> /dev/null
pushd $MINGW_PREFIX/bin
cp -f $NEEDED_DLLS $QT6_STATIC_PREFIX/bin
popd

sed -e 's/-Dmain=SDL_main//g' $MINGW_PREFIX/lib/pkgconfig/sdl2.pc > $MINGW_PREFIX/lib/pkgconfig/sdl2_withqt.pc
}

# Use the right mkspecs file
if [[ ${MINGW_PACKAGE_PREFIX} == *-clang-* ]]; then
  _platform=win32-clang-g++
else
  _platform=win32-g++
fi

# Helper macros to help make tasks easier #
apply_patch_with_msg() {
  for _patch in "$@"
  do
    echo "Applying ${_patch}"
    patch -Nbp1 -i "${SCRIPT_DIR}/${_patch}"
    exitOnError
  done
}

QT_MAJOR_VERSION=6.8
QT_MINOR_VERSION=.3
QT_VERSION=$QT_MAJOR_VERSION$QT_MINOR_VERSION

function makeQtSourceTree(){
#Qt
QT_ARCHIVE_DIR=qt-everywhere-src-$QT_VERSION
QT_ARCHIVE=$QT_ARCHIVE_DIR.tar.xz
QT_SOURCE_DIR=qt6-src-$1
#QT_RELEASE=development_releases
QT_RELEASE=official_releases


if [ -e $QT_SOURCE_DIR ]; then
  # 存在する場合
  echo "$QT_SOURCE_DIR already exists."
else
  # 存在しない場合
  if [ ! -e $QT_ARCHIVE ]; then
  wget -c  http://download.qt.io/$QT_RELEASE/qt/$QT_MAJOR_VERSION/$QT_VERSION/single/$QT_ARCHIVE
  fi

  pv $QT_ARCHIVE | tar -xJ
  mv $QT_ARCHIVE_DIR $QT_SOURCE_DIR
  pushd $QT_SOURCE_DIR

  apply_patch_with_msg \
    001-adjust-qmake-conf-mingw.patch \
    002-qt-6.2.0-win32-g-Add-QMAKE_EXTENSION_IMPORTLIB-defaulting-to-.patch \
    003-qt-6.2.0-dont-add-resource-files-to-qmake-libs.patch \
    004-Allow-overriding-CMAKE_FIND_LIBRARY_SUFFIXES-to-pref.patch \
    005-qt-6.2.0-win32static-cmake-link-ws2_32-and--static.patch \
    006-Fix-finding-D-Bus.patch \
    007-Fix-using-static-PCRE2-and-DBus-1.patch \
    008-Fix-libjpeg-workaround-for-conflict-with-rpcndr.h.patch \
    009-Fix-transitive-dependencies-of-static-libraries.patch \
    010-Support-finding-static-MariaDB-client-library.patch \
    011-Fix-crashes-in-rasterization-code-using-setjmp.patch \
    012-Handle-win64-in-dumpcpp-and-MetaObjectGenerator-read.patch \
    013-disable-finding-webp-from-cmake-config-files.patch \
    014-imageformats-transitive-dependencies.patch \
    015-qt6-windeployqt-fixes.patch

  cd qtquick3d/src/3rdparty/assimp/src
  apply_patch_with_msg \
    016-fix-build-on-mingw64.patch
  cd -

  local _ARCH_TUNE
  if [[ ${CARCH} == x86_64 ]]; then
    _ARCH_TUNE="-march=nocona -msahf -mtune=generic"
  fi

  BIGOBJ_FLAGS="-Wa,-mbig-obj"

  # Append these ones ..
  sed -i "s|^QMAKE_CFLAGS .*= \(.*\)$|QMAKE_CFLAGS            = \1 ${_ARCH_TUNE} ${BIGOBJ_FLAGS}|g" qtbase/mkspecs/${_platform}/qmake.conf
  sed -i "s|^QMAKE_CXXFLAGS .*= \(.*\)$|QMAKE_CXXFLAGS            = \1 ${_ARCH_TUNE} ${BIGOBJ_FLAGS}|g" qtbase/mkspecs/${_platform}/qmake.conf

  popd
fi

}


function buildQtStatic(){
if [ -e $QT6_STATIC_PREFIX/bin/qmake.exe -a $((FORCE_INSTALL)) == 0 ]; then
    echo "Qt6 Static Libs are already installed."
    return 0
fi

#Qtのソースコードを展開
makeQtSourceTree static
exitOnError

#static版
QT6_STATIC_BUILD=qt6-static-$MSYSTEM
rm -rf $QT6_STATIC_BUILD
mkdir $QT6_STATIC_BUILD
pushd $QT6_STATIC_BUILD
#---------------------------------------------------
  CXXFLAGS+=" -Wno-invalid-constexpr" \
  PKG_CONFIG_ARGN="--static" \
  LDFLAGS+=" -static -static-libgcc -static-libstdc++" \
  MSYS2_ARG_CONV_EXCL="-DCMAKE_INSTALL_PREFIX=;-DCMAKE_CONFIGURATION_TYPES=;-DCMAKE_FIND_LIBRARY_SUFFIXES=" \
  ${MINGW_PREFIX}/bin/cmake \
    -Wno-dev \
    --log-level=STATUS \
    -G "Ninja" \
    -DCMAKE_BUILD_TYPE=Release \
    -DFEATURE_optimize_size=OFF \
    -DBUILD_WITH_PCH=OFF \
    -DCMAKE_FIND_LIBRARY_SUFFIXES_OVERRIDE=".a" \
    -DBUILD_SHARED_LIBS=OFF \
    -DQT_QMAKE_TARGET_MKSPEC=${_platform} \
    -DCMAKE_INSTALL_PREFIX=$(cygpath -am $QT6_STATIC_PREFIX) \
    -DINSTALL_BINDIR=bin \
    -DINSTALL_LIBDIR=lib \
    -DINSTALL_INCLUDEDIR=include/qt6 \
    -DINSTALL_ARCHDATADIR=share/qt6 \
    -DINSTALL_DOCDIR=share/doc/qt6 \
    -DINSTALL_DATADIR=share/qt6 \
    -DINSTALL_MKSPECSDIR=share/qt6/mkspecs \
    -DINSTALL_DESCRIPTIONSDIR=share/qt6/modules \
    -DINSTALL_TESTSDIR=share/qt6/tests \
    -DINSTALL_EXAMPLESDIR=share/doc/qt6/examples \
    -DFEATURE_static_runtime=ON \
    -DFEATURE_relocatable=ON \
    -DFEATURE_openssl_linked=ON \
    -DINPUT_openssl=linked \
    -DINPUT_dbus=linked \
    -DINPUT_mng=no \
    -DINPUT_jasper=no \
    -DINPUT_libmd4c=qt \
    -DFEATURE_glib=OFF \
    -DINPUT_quick3d_assimp=qt \
    -DFEATURE_system_assimp=OFF \
    -DFEATURE_system_doubleconversion=OFF \
    -DFEATURE_system_freetype=OFF \
    -DFEATURE_system_harfbuzz=OFF \
    -DFEATURE_system_jpeg=OFF \
    -DFEATURE_system_pcre2=OFF \
    -DFEATURE_system_png=OFF \
    -DFEATURE_system_sqlite=OFF \
    -DFEATURE_system_tiff=OFF \
    -DFEATURE_system_webp=OFF \
    -DFEATURE_system_zlib=OFF \
    -DFEATURE_opengl=ON \
    -DFEATURE_opengl_desktop=OFF \
    -DFEATURE_egl=OFF \
    -DFEATURE_gstreamer=OFF \
    -DFEATURE_icu=OFF \
    -DFEATURE_fontconfig=OFF \
    -DFEATURE_pkg_config=ON \
    -DFEATURE_vulkan=ON \
    -DFEATURE_sql_ibase=OFF \
    -DFEATURE_sql_psql=OFF \
    -DFEATURE_sql_mysql=OFF \
    -DFEATURE_sql_odbc=OFF \
    -DFEATURE_zstd=OFF \
    -DFEATURE_wmf=ON \
    -DFEATURE_ffmpeg=OFF \
    -DQT_BUILD_TESTS=OFF \
    -DQT_BUILD_EXAMPLES=OFF \
    -DOPENSSL_DEPENDENCIES="-lws2_32;-lgdi32;-lcrypt32" \
    -DLIBPNG_DEPENDENCIES="-lz" \
    -DGLIB2_DEPENDENCIES="-lintl;-lws2_32;-lole32;-lwinmm;-lshlwapi;-lm" \
    -DFREETYPE_DEPENDENCIES="-lbz2;-lharfbuzz;-lfreetype;-lbrotlidec;-lbrotlicommon" \
    -DHARFBUZZ_DEPENDENCIES="-lglib-2.0;-lintl;-lws2_32;-lusp10;-lgdi32;-lole32;-lwinmm;-lshlwapi;-lintl;-lm;-lfreetype;-lgraphite2;-lrpcrt4" \
    -DDBUS1_DEPENDENCIES="-lws2_32;-liphlpapi;-ldbghelp" \
    -DPython_EXECUTABLE=${MINGW_PREFIX}/bin/python \
    -DOPENSSL_USE_STATIC_LIBS=ON \
    -DZLIB_USE_STATIC_LIBS=ON \
    -DBUILD_qtwebengine=OFF \
    $(cygpath -am ../$QT_SOURCE_DIR) 

    #カスタマイズポイント
    # -DCMAKE_INSTALL_PREFIX=$(cygpath -am $QT6_STATIC_PREFIX) \
    # -DCMAKE_BUILD_TYPE=MinSizeRel \
    # -DFEATURE_optimize_size=ON \
    # -DBUILD_WITH_PCH=OFF \
    # -DINPUT_jasper=no \
    # -DFEATURE_SYSTEM_*=OFF
    # -DFEATURE_opengl_desktop=OFF \
    # -DFEATURE_ffmpeg=OFF \
    # 最後のソースパス↓
    # $(cygpath -am ../$QT_SOURCE_DIR) 

#---------------------------------------------------

  export PATH=$PWD/bin:$PATH

cp config.summary ../qt6_config_summary_$MSYSTEM.txt

nice -n19 cmake --build .
exitOnError

cmake --install .
exitOnError


popd

# rm -rf $QT6_STATIC_BUILD
}



#----------------------------------------------------
SCRIPT_DIR=$(dirname $(readlink -f ${BASH_SOURCE:-$0}))
source $SCRIPT_DIR/../common/common.sh
commonSetup

#必要ライブラリ
prerequisite

export PKG_CONFIG="$(cygpath -am $MINGW_PREFIX/bin/pkg-config.exe)"
export LLVM_INSTALL_DIR=$(cygpath -am $MINGW_PREFIX)

#Qtのインストール場所
QT6_STATIC_PREFIX=$PREFIX/qt6-static-private

cd $EXTLIB

#static版Qtをビルド
buildQtStatic
exitOnError

