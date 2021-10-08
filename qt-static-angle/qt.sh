#!/bin/bash

function prerequisite(){
#必要ライブラリ
pacman "${PACMAN_INSTALL_OPTS[@]}" \
$MINGW_PACKAGE_PREFIX-ntldd \
$MINGW_PACKAGE_PREFIX-clang \
$MINGW_PACKAGE_PREFIX-clang-tools-extra \
$MINGW_PACKAGE_PREFIX-SDL2 \
$MINGW_PACKAGE_PREFIX-dbus \
$MINGW_PACKAGE_PREFIX-openssl \
2> /dev/null

exitOnError

mkdir -p $PREFIX/bin 2> /dev/null
mkdir -p $QT5_STATIC_PREFIX/bin 2> /dev/null
pushd $MINGW_PREFIX/bin
cp -f $NEEDED_DLLS $QT5_STATIC_PREFIX/bin
popd
}

function makeQtSourceTree(){
#Qt
QT_MAJOR_VERSION=5.12
QT_MINOR_VERSION=.6
QT_VERSION=$QT_MAJOR_VERSION$QT_MINOR_VERSION
QT_ARCHIVE_DIR=qt-everywhere-src-$QT_VERSION
QT_ARCHIVE=$QT_ARCHIVE_DIR.tar.xz
QT_SOURCE_DIR=qt-src-$QT_VERSION-$1
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

    tar xf $QT_ARCHIVE
    mv $QT_ARCHIVE_DIR $QT_SOURCE_DIR
    pushd $QT_SOURCE_DIR

    #共通パッチ
    patch -p1 -i $SCRIPT_DIR/0301-link-evr.patch
    patch -p1 -i $SCRIPT_DIR/0052-qt-5.11-mingw-fix-link-qdoc-with-clang.patch
    patch -p1 -i $SCRIPT_DIR/0059-different-libs-search-order-for-static-and-shared.patch

    if [ "$1" == "static" ]; then
        #static版がcmakeで正常にリンクできない対策のパッチ
        patch -p1 -i $SCRIPT_DIR/0034-qt-5.3.2-Use-QMAKE_PREFIX_STATICLIB-in-create_cmake-prf.patch
        patch -p1 -i $SCRIPT_DIR/0035-qt-5.3.2-dont-add-resource-files-to-qmake-libs.patch
        
        # Patches so that qt5-static can be used with cmake.
        patch -p1 -i $SCRIPT_DIR/0036-qt-5.3.2-win32-qt5-static-cmake-link-ws2_32-and--static.patch
        patch -p1 -i $SCRIPT_DIR/0037-qt-5.4.0-Improve-cmake-plugin-detection-as-not-all-are-suffixed-Plugin.patch
        patch -p1 -i $SCRIPT_DIR/0038-qt-5.5.0-cmake-Rearrange-STATIC-vs-INTERFACE-targets.patch
        patch -p1 -i $SCRIPT_DIR/0039-qt-5.4.0-Make-it-possible-to-use-static-builds-of-Qt-with-CMa.patch
        patch -p1 -i $SCRIPT_DIR/0040-qt-5.4.0-Generate-separated-libraries-in-prl-files-for-CMake.patch
        patch -p1 -i $SCRIPT_DIR/0041-qt-5.4.0-Fix-mingw-create_cmake-prl-file-has-no-lib-prefix.patch
        patch -p1 -i $SCRIPT_DIR/0042-qt-5.4.0-static-cmake-also-link-plugins-and-plugin-deps.patch
        patch -p1 -i $SCRIPT_DIR/0043-qt-5.5.0-static-cmake-regex-QT_INSTALL_LIBS-in-QMAKE_PRL_LIBS_FOR_CMAKE.patch

        #qdocのビルドが通らないので暫定パッチ
        patch -p1 -i $SCRIPT_DIR/0302-ugly-hack-disable-qdoc-build.patch
    fi

    #MSYSでビルドが通らない問題への対策パッチ
    for F in qtbase/src/angle/src/common/gles_common.pri qtdeclarative/features/hlsl_bytecode_header.prf
    do
        sed -i -e "s|/nologo |//nologo |g" $F
        sed -i -e "s|/E |//E |g" $F
        sed -i -e "s|/T |//T |g" $F
        sed -i -e "s|/Fh |//Fh |g" $F
    done

    #64bit環境で生成されるオブジェクトファイルが巨大すぎでビルドが通らない問題へのパッチ
    sed -i -e "s|QMAKE_CFLAGS           = |QMAKE_CFLAGS         = -Wa,-mbig-obj |g" qtbase/mkspecs/win32-g++/qmake.conf

    #プリコンパイル済みヘッダーが巨大すぎでビルドが通らない問題へのパッチ
    sed -i -e "s| precompile_header||g" qtbase/mkspecs/win32-g++/qmake.conf

    popd
fi

#共通ビルドオプション
QT_COMMON_CONF_OPTS=()
QT_COMMON_CONF_OPTS+=("-opensource")
QT_COMMON_CONF_OPTS+=("-confirm-license")
QT_COMMON_CONF_OPTS+=("-silent")
QT_COMMON_CONF_OPTS+=("-platform" "win32-g++")
QT_COMMON_CONF_OPTS+=("-release")
QT_COMMON_CONF_OPTS+=("-optimize-size")
QT_COMMON_CONF_OPTS+=("-pkg-config")
QT_COMMON_CONF_OPTS+=("-no-pch")
QT_COMMON_CONF_OPTS+=("QMAKE_CXXFLAGS+=-Wno-deprecated-declarations")
QT_COMMON_CONF_OPTS+=("-no-direct2d")
QT_COMMON_CONF_OPTS+=("-no-fontconfig")
QT_COMMON_CONF_OPTS+=("-qt-zlib")
QT_COMMON_CONF_OPTS+=("-qt-libjpeg")
QT_COMMON_CONF_OPTS+=("-qt-libpng")
QT_COMMON_CONF_OPTS+=("-qt-tiff")
QT_COMMON_CONF_OPTS+=("-no-mng")
QT_COMMON_CONF_OPTS+=("-no-jasper")
QT_COMMON_CONF_OPTS+=("-qt-webp")
QT_COMMON_CONF_OPTS+=("-qt-freetype")
QT_COMMON_CONF_OPTS+=("-qt-pcre")
QT_COMMON_CONF_OPTS+=("-qt-harfbuzz")
QT_COMMON_CONF_OPTS+=("-nomake" "tests")
QT_COMMON_CONF_OPTS+=("-no-feature-openal")
QT_COMMON_CONF_OPTS+=("-skip" "qtdeclarative")
}


function buildQtStatic(){
if [ -e $QT5_STATIC_PREFIX/bin/qmake.exe -a $((FORCE_INSTALL)) == 0 ]; then
    echo "Qt5 Static Libs are already installed."
    return 0
fi

#Qtのソースコードを展開
makeQtSourceTree static
exitOnError

#static版
QT5_STATIC_BUILD=qt5-static-$BIT
rm -rf $QT5_STATIC_BUILD
mkdir $QT5_STATIC_BUILD
pushd $QT5_STATIC_BUILD

QT_STATIC_CONF_OPTS=()
QT_STATIC_CONF_OPTS+=("-v")
QT_STATIC_CONF_OPTS+=("-prefix" "$(cygpath -am $QT5_STATIC_PREFIX)")
QT_STATIC_CONF_OPTS+=("-angle")
QT_STATIC_CONF_OPTS+=("-static")
QT_STATIC_CONF_OPTS+=("-static-runtime")
QT_STATIC_CONF_OPTS+=("-nomake" "examples")
QT_STATIC_CONF_OPTS+=("-D" "JAS_DLL=0")
QT_STATIC_CONF_OPTS+=("-openssl-linked")
QT_STATIC_CONF_OPTS+=("-no-dbus")

export QDOC_SKIP_BUILD=1
export QDOC_USE_STATIC_LIBCLANG=1
OPENSSL_LIBS="$(pkg-config --static --libs openssl)" \
../$QT_SOURCE_DIR/configure "${QT_COMMON_CONF_OPTS[@]}" "${QT_STATIC_CONF_OPTS[@]}" &> ../qt5-static-$BIT-config.status
exitOnError

makeParallel && make install
exitOnError

#MSYS2のlibtiffはliblzmaに依存しているためリンクを追加する
sed -i -e "s|-ltiff|-ltiff -llzma|g" $QT5_STATIC_PREFIX/plugins/imageformats/qtiff.prl
sed -i -e "s|-ltiff|-ltiff -llzma|g" $QT5_STATIC_PREFIX/plugins/imageformats/qtiffd.prl

popd

unset QDOC_SKIP_BUILD
unset QDOC_USE_STATIC_LIBCLANG
rm -rf $QT5_STATIC_BUILD
}



#----------------------------------------------------
SCRIPT_DIR=$(dirname $(readlink -f ${BASH_SOURCE:-$0}))
source $SCRIPT_DIR/../common/common.sh
commonSetup

export WindowsSdkVerBinPath="C:/Program Files (x86)/Windows Kits/10/bin/10.0.18362.0"
export PKG_CONFIG="$(cygpath -am $MINGW_PREFIX/bin/pkg-config.exe)"
export LLVM_INSTALL_DIR=${MINGW_PREFIX}

#Qtのインストール場所
QT5_STATIC_PREFIX=$PREFIX/qt5-static-angle

#必要ライブラリ
prerequisite

cd $EXTLIB

#static版Qtをビルド
buildQtStatic
exitOnError

