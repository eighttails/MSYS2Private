#!/bin/bash

#function prerequisite(){
#}

function build(){
if [ -e $PREFIX/bin/twaindsm.dll -a $((FORCE_INSTALL)) == 0 ]; then
echo "TWAIN DSM is already installed."
exit 0
fi

#TWAINDSM_VERSION=4.00.00alpha
TWAINDSM_VERSION=2.3.1
TWAINDSM_TAG=$TWAINDSM_VERSION
TWAINDSM_ARCHIVE=twaindsm-$TWAINDSM_TAG.source.zip
TWAINDSM_SRC_DIR=twaindsm-$TWAINDSM_TAG.orig
TWAINDSM_BUILD_DIR=$TWAINDSM_SRC_DIR-$MINGW_CHOST


wget https://sourceforge.net/projects/twain-dsm/files/TWAIN%20DSM%202%20Source/$TWAINDSM_ARCHIVE
rm -rf $TWAINDSM_SRC_DIR $TWAINDSM_BUILD_DIR 
unzip $TWAINDSM_ARCHIVE
mv $TWAINDSM_SRC_DIR $TWAINDSM_BUILD_DIR
pushd $TWAINDSM_BUILD_DIR


patch -p1 --binary < $SCRIPT_DIR/twaindsm_mingw.patch
pushd TWAIN_DSM/src
#sed -i -e "s/LIBRARY DESTINATION/RUNTIME DESTINATION/g" CMakeLists.txt
mkdir build
pushd build
cmake .. \
-G"MSYS Makefiles" \
-DCMAKE_INSTALL_PREFIX=$PREFIX 
exitOnError

makeParallel && makeParallel install
exitOnError
popd
popd
popd
}

#-----------------------------
SCRIPT_DIR=$(dirname $(readlink -f ${BASH_SOURCE:-$0}))
source $SCRIPT_DIR/../common/common.sh
commonSetup
#prerequisite

cd $EXTLIB

build
