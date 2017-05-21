#!/bin/bash

function prerequisite(){
#他スクリプト依存関係
#if [ $((NO_DEPENDENCY)) == 0 ]; then
#$SCRIPT_DIR/../foo/foo.sh
#exitOnError
#fi

#必要ライブラリ
pacman -S --needed --noconfirm \
$MINGW_PACKAGE_PREFIX-aspell \
$MINGW_PACKAGE_PREFIX-hunspell

}

function build(){
if [ -e $PREFIX/lib/libenchant.a -a $((FORCE_INSTALL)) == 0 ]; then
echo "enchant is already installed."
exit 0
fi

ENCHANT_SRC_DIR=enchant-$MINGW_CHOST

if [ ! -d  $ENCHANT_SRC_DIR ]; then
git clone https://github.com/AbiWord/enchant.git $ENCHANT_SRC_DIR
fi

pushd $ENCHANT_SRC_DIR
git pull

./bootstrap 

./configure \
--build=$MINGW_CHOST \
--host=$MINGW_CHOST \
--target=$MINGW_CHOST \
--prefix=$PREFIX \
--with-extra-includes=$PREFIX/include \
--with-extra-libraries=$PREFIX/lib \
--enable-relocatable

exitOnError

makeParallel && makeParallel install
exitOnError
popd
}

#-----------------------------
SCRIPT_DIR=$(dirname $(readlink -f ${BASH_SOURCE:-$0}))
source $SCRIPT_DIR/../common/common.sh
commonSetup

prerequisite
exitOnError

cd $EXTLIB

build
exitOnError
