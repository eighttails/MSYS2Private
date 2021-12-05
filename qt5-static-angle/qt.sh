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
QT_GIT_DIR=kde-qt5-git
QT_SOURCE_DIR=qt5-src-$1

if [ -e $QT_SOURCE_DIR ]; then
    # 存在する場合
    echo "$QT_SOURCE_DIR already exists."
else
    # 存在しない場合
    if [ ! -e $QT_GIT_DIR ]; then
        #KDEリポジトリのパッチ適用済みリポジトリを取得
        git clone --recurse-submodules -b kde/5.15 https://invent.kde.org/qt/qt/qt5 $QT_GIT_DIR
        # git clone -b kde/5.15 https://invent.kde.org/qt/qt/qt5 $QT_GIT_DIR
        # pushd $QT_GIT_DIR
        # perl init-repository
        # popd
    else
        pushd $QT_GIT_DIR
        git pull
        popd
    fi

    # 独自パッチ適用用のワークフォルダにコピー
    # rsync -a --no-compress --exclude='.git/' $QT_GIT_DIR/ $QT_SOURCE_DIR 
    cp -r $QT_GIT_DIR $QT_SOURCE_DIR 
    pushd $QT_SOURCE_DIR
    # rm -rf .git

    #qdocのビルドが通らないので暫定パッチ
    if [ "$1" == "static" ]; then
        patchOnce 1 $SCRIPT_DIR/0302-ugly-hack-disable-qdoc-build.patch
        patchOnce 1 $SCRIPT_DIR/0100-fix-relocatable-prefix-staticbuild-v2.patch
    fi

    #MSYSで引数のパス変換が勝手に走ってビルドが通らない問題への対策パッチ
    for F in qtbase/src/angle/src/common/gles_common.pri qtdeclarative/features/hlsl_bytecode_header.prf
    do
        sed -i -e "s|/nologo |//nologo |g" $F
        sed -i -e "s|/E |//E |g" $F
        sed -i -e "s|/T |//T |g" $F
        sed -i -e "s|/Fh |//Fh |g" $F
    done
    sed -i -e "s|load(qt_tool)|msysargconv.name = MSYS2_ARG_CONV_EXCL\nmsysargconv.value = *\nQT_TOOL_ENV += msysargconv\nload(qt_tool)|" qtdeclarative/src/qmltyperegistrar/qmltyperegistrar.pro

    #64bit環境で生成されるオブジェクトファイルが巨大すぎでビルドが通らない問題へのパッチ
    sed -i -e "s|QMAKE_CFLAGS           = |QMAKE_CFLAGS         = -Wa,-mbig-obj |g" qtbase/mkspecs/win32-g++/qmake.conf

    #プリコンパイル済みヘッダーが巨大すぎでビルドが通らない問題へのパッチ
    sed -i -e "s| precompile_header||g" qtbase/mkspecs/win32-g++/qmake.conf

    popd #QT_SOURCE_DIR
fi

#共通ビルドオプション
QT_COMMON_CONF_OPTS=()
QT_COMMON_CONF_OPTS+=("-opensource")
QT_COMMON_CONF_OPTS+=("-confirm-license")
QT_COMMON_CONF_OPTS+=("-silent")
QT_COMMON_CONF_OPTS+=("-platform" "win32-g++")
QT_COMMON_CONF_OPTS+=("-optimize-size")
QT_COMMON_CONF_OPTS+=("-pkg-config")
QT_COMMON_CONF_OPTS+=("-no-pch")
QT_COMMON_CONF_OPTS+=("QMAKE_CXXFLAGS+=-Wno-deprecated-declarations")
QT_COMMON_CONF_OPTS+=("-no-direct2d")
QT_COMMON_CONF_OPTS+=("-no-wmf")
QT_COMMON_CONF_OPTS+=("-no-mng")
QT_COMMON_CONF_OPTS+=("-no-fontconfig")
QT_COMMON_CONF_OPTS+=("-qt-zlib")
QT_COMMON_CONF_OPTS+=("-qt-libjpeg")
QT_COMMON_CONF_OPTS+=("-qt-libpng")
QT_COMMON_CONF_OPTS+=("-qt-tiff")
QT_COMMON_CONF_OPTS+=("-no-jasper")
QT_COMMON_CONF_OPTS+=("-qt-webp")
QT_COMMON_CONF_OPTS+=("-qt-freetype")
QT_COMMON_CONF_OPTS+=("-qt-pcre")
QT_COMMON_CONF_OPTS+=("-qt-harfbuzz")
QT_COMMON_CONF_OPTS+=("-nomake" "tests")
QT_COMMON_CONF_OPTS+=("-no-feature-openal")
QT_COMMON_CONF_OPTS+=("-no-feature-d3d12")
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
QT_STATIC_CONF_OPTS+=("-verbose")
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
../$QT_SOURCE_DIR/configure.bat "${QT_COMMON_CONF_OPTS[@]}" "${QT_STATIC_CONF_OPTS[@]}" &> ../qt5-static-$BIT-config.status
exitOnError

makeParallel && make install
exitOnError

popd

unset QDOC_SKIP_BUILD
unset QDOC_USE_STATIC_LIBCLANG
rm -rf $QT5_STATIC_BUILD
}



#----------------------------------------------------
SCRIPT_DIR=$(dirname $(readlink -f ${BASH_SOURCE:-$0}))
source $SCRIPT_DIR/../common/common.sh
commonSetup

#ANGLEをビルドするために必要なfxc.exeにパスを通す
export WindowsSdkVerBinPath=$(cygpath -am "C:/Program Files (x86)/Windows Kits/10/bin/10.0.22000.0")
export PATH=$(cygpath "$WindowsSdkVerBinPath/$ARCH"):$PATH

export PKG_CONFIG="$(cygpath -am $MINGW_PREFIX/bin/pkg-config.exe)"
export LLVM_INSTALL_DIR=$(cygpath -am ${MINGW_PREFIX})

# https://github.com/msys2/MSYS2-packages/issues/2282
export MSYS2_ARG_CONV_EXCL='--foreign-types='

#Qtのインストール場所
QT5_STATIC_PREFIX=$PREFIX/qt5-static-angle

#必要ライブラリ
prerequisite

cd $EXTLIB

#static版Qtをビルド
buildQtStatic
exitOnError

