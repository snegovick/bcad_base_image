#!/bin/bash

echo "======================"
echo "Getting version"
echo "======================"

set -e

PYPKG_NAME="bcad"
VSTRING=$(grep version setup.py | sed "s/ *version = \"//" | sed "s/\",//")
echo "VSTRING: ${VSTRING}"
PKG_VERSION=$( git rev-list --all --count )
echo "PKG_VERSION: ${PKG_VERSION}"

APPIMAGE="bcad-${PKG_VERSION}-x86_64.AppImage"

if [ ! -e bcad.AppDir_t ]; then
    mkdir bcad.AppDir_t
fi
if [ -e bcad.AppDir ]; then
    rm -rf bcad.AppDir
fi
ROOTDIR=$(pwd)
APPDIR=${ROOTDIR}/bcad.AppDir
pushd bcad.AppDir_t
APPDIR_T=$(pwd)

BASE_URL=http://archive.main.int

OCC_NAME=opencascade-7.4.0
OCC_ARC_NAME=${OCC_NAME}.tgz
OCC740_URL=${BASE_URL}/archive/${OCC_ARC_NAME}
OCC_BUILD_DIR=occ_build

PYOCC_BUILD_DIR=pyocc_build
PYOCC_GIT=pythonocc-core
PYOCC_GIT_URL=https://github.com/snegovick/pythonocc-core.git

echo "======================"
echo "Obtain appimagetool"
echo "======================"

pushd /tmp
if [ -e appimagetool-x86_64.AppImage ]; then
    rm appimagetool-x86_64.AppImage
fi
#wget https://github.com/probonopd/AppImageKit/releases/download/12/appimagetool-x86_64.AppImage
wget http://archive.main.int/archive/appimagetool-x86_64.AppImage
chmod +x appimagetool-x86_64.AppImage
popd
popd

DEBOOTSTRAP=0
MINICONDA=1

MINICONDA_PKG=Miniconda3-py38_4.8.3-Linux-x86_64.sh

if [ ${MINICONDA} -eq 1 ]; then
    echo "Checking miniconda"
    pushd ${APPDIR_T}
    if [ ! -e usr/bin ]; then
        echo "Installing miniconda"
        PKG=${MINICONDA_PKG}
        if [ ! -e ${PKG} ]; then
            wget http://archive.main.int/archive/${PKG}
            bash ${PKG} -b -p usr -f
        fi
        echo "Activating envinronment"
        source usr/bin/activate
        echo "Installing deps"
        usr/bin/pip install --force-reinstall PyOpenGL PyOpenGL_accelerate numpy watchdog pyinotify ply glfw imgui[glfw]
        echo "pip: $(which -a pip)"
    else
        echo "Miniconda already installed, skip"
        echo "Activating envinronment"
        source usr/bin/activate
    fi

    if [ ! -e ${OCC_NAME} ]; then
    	  echo "Obtaining OpenCASCADE"
        curl ${OCC740_URL} -o ${OCC_ARC_NAME}
        tar -xf ${OCC_ARC_NAME}
    else
        echo "OpenCASCADE already unpacked, skip"
    fi

    if [ ! -e ${OCC_BUILD_DIR} ]; then
    	  echo "Building OpenCASCADE"
        mkdir ${OCC_BUILD_DIR}
        pushd ${OCC_BUILD_DIR}
        cmake -DINSTALL_DIR=${APPDIR_T}/usr -DUSE_VTK=yes -DUSE_RAPIDJSON=yes -DUSE_FREEIMAGE=yes -DUSE_FFMPEG=yes ../${OCC_NAME}
        make -j $(nproc)
        make install -j $(nproc)
        popd
    else
        echo "OpenCASCADE already built, skip"
    fi

    if [ ! -e ${PYOCC_GIT} ]; then
    	  echo "Obtaining Python-OCC"
        git clone ${PYOCC_GIT_URL} -b bcad_noswap_7.4.0
    else
        echo "Python-OCC git already cloned, skip"
    fi

    if [ ! -e ${PYOCC_BUILD_DIR} ]; then
    	  echo "Building Python-OCC"
        mkdir ${PYOCC_BUILD_DIR}
        pushd ${PYOCC_BUILD_DIR}
        PATH=${APPDIR_T}/usr/bin:${PATH} /usr/bin/cmake -DCMAKE_INSTALL_PREFIX=${APPDIR_T}/usr -DPYTHONOCC_INSTALL_DIRECTORY=${APPDIR_T}/usr/lib/python3/site-packages/OCC -DOpenCASCADE_DIR=${APPDIR_T}/usr/lib/cmake/opencascade -DPython3_FIND_VIRTUALENV=ONLY  ../${PYOCC_GIT}
        make -j $(nproc)
        make install -j $(nproc)
        popd
    else
        echo "Python-OCC already built, skip"        
    fi

    if [ ! -e ezdxf ]; then
        git clone https://github.com/snegovick/ezdxf.git
        pushd ezdxf
        git checkout 1070c67779f75c707c8817b2cc2eca87154fdab5 -b build
        ${APPDIR_T}/usr/bin/python3.8 setup.py build -j$(nproc) install --prefix ${APPDIR_T}/usr
        popd
    fi

    popd

    if [ ! -n "$(find ${APPDIR_T}/usr/lib/python3/site-packages/ -maxdepth 0 -empty)" ]; then
        echo "Copy all modules into python3.8 path"
        mv ${APPDIR_T}/usr/lib/python3/site-packages/* ${APPDIR_T}/usr/lib/python3.8
    else
        echo "Modules are already moved into python3.8 path"
    fi

    cp -pr ${APPDIR_T} ${APPDIR}

        pushd ${APPDIR}

    echo "Clean up image"
    
    # rm -f bin
    # rm -rf boot
    # rm -rf etc
    # rm -f dev
    rm -rf ezdxf
    # rm -f lib32
    # #rm -f lib64
    # rm -rf media
    # rm -rf mnt
    rm -rf occ_build
    rm -rf opencascade-7.4.0
    rm opencascade-7.4.0.tgz
    # rm -rf opt
    # rm -f proc
    rm -rf pyocc_build
    rm -rf pythonocc-core
    rm  ${MINICONDA_PKG}
    # rm -rf run
    # rm -f sbin
    # rm -rf srv
    # rm -rf sys
    # rm -rf tmp
    # rm -rf var
    # rm -rf home
    # rm -f libx32

    pushd usr/bin
    find . ! -name python3.8 ! -name bcad-launcher -maxdepth 1 -type f -delete
    popd

    ACTUALLY_RM=0

    # pushd usr/lib/x86_64-linux-gnu
    # if [ -e ${ROOTDIR}/packaging/keep.list ]; then
    #     for i in *; do
    #         if ! grep -qxFe "$i" ${ROOTDIR}/packaging/keep.list; then
    #             if [ ${ACTUALLY_RM} -eq 1 ]; then
    #                 echo "Deleting: $i"
    #                 rm -rf "$i"
    #             else
    #                 echo "Pretending to delete $i"
    #             fi
    #         fi
    #     done
    # else
    #     echo "Error: ${ROOTDIR}/packaging/keep.list is missing"
    #     exit 1
    # fi
    # popd

    ACTUALLY_RM=1
    pushd usr/lib
    if [ -e ${ROOTDIR}/packaging/keep.list ]; then
        for i in *; do
            if ! grep -qxFe "$i" ${ROOTDIR}/packaging/keep.list; then
                if [ ${ACTUALLY_RM} -eq 1 ]; then
                    echo "Deleting: $i"
                    rm -rf "$i"
                else
                    echo "Pretending to delete $i"
                fi
            fi
        done
    else
        echo "Error: ${ROOTDIR}/packaging/keep.list is missing"
        exit 1
    fi
    popd


    rm -rf usr/compiler_compat
    rm -rf usr/conda-meta
    rm -rf usr/condabin
    rm -rf usr/envs
    rm -rf usr/etc
    rm -rf usr/include
    rm -rf usr/pkgs
    rm -rf usr/share
    rm -rf usr/shell
    rm -rf usr/ssl
    mv usr/LICENSE.txt usr/CONDA_LICENSE.txt
fi

tar cvf ${APPDIR}.tar ${APPDIR}
xz ${APPDIR}.tar
