function build_gmp {
    local version=$1
    local url=$2
    if [ -e gmp-stamp ]; then
       return;
    fi
    fetch_unpack $url/gmp-${version}.tar.bz2
    (cd gmp-${version} \
        && ./configure --prefix=$BUILD_PREFIX --enable-fat --disable-shared --enable-static \
        && make \
        && make install)
    touch gmp-stamp
}


function build_simple2 {
    local name=$1
    local version=$2
    local url=$3
    if [ -e "${name}-stamp" ]; then
        return
    fi
    local name_version="${name}-${version}"
    local targz=${name_version}.tar.gz
    fetch_unpack $url/$targz
    (cd $name_version \
        && ./configure --prefix=$BUILD_PREFIX --disable-shared --enable-static \
        && make \
        && make install)
    touch "${name}-stamp"
}

function pre_build {
    set -x
    build_gmp 6.1.2 https://gmplib.org/download/gmp
    build_simple2 mpfr 3.1.5 http://ftp.gnu.org/gnu/mpfr
    build_simple2 mpc 1.0.3 http://www.multiprecision.org/mpc/download
}

function run_tests {
    # Runs tests on installed distribution from an empty directory
    python --version
    python -c "import gmpy2"
}

if [ -n "$IS_OSX" ]; then
    function build_wheel {
        local repo_dir=${1:-$REPO_DIR}
        local wheelhouse=$(abspath ${WHEEL_SDIR:-wheelhouse})
        # Build dual arch wheel
        export CC=clang
        export CXX=clang++
        install_pkg_config
        # 32-bit wheel
        export ABI="32"
        export CFLAGS="-arch i386"
        export FFLAGS="-arch i386"
        export LDFLAGS="-arch i386"
        # Build libraries
        source multibuild/library_builders.sh
        pre_build
        # Build wheel
        local py_ld_flags="-Wall -undefined dynamic_lookup -bundle"
        local wheelhouse32=${wheelhouse}32
        mkdir -p $wheelhouse32
        export LDFLAGS="$LDFLAGS $py_ld_flags"
        export LDSHARED="clang $LDFLAGS $py_ld_flags"
        build_pip_wheel "$repo_dir"
        mv ${wheelhouse}/*whl $wheelhouse32
        # 64-bit wheel
        export ABI="64"
        export CFLAGS="-arch x86_64"
        export FFLAGS="-arch x86_64"
        export LDFLAGS="-arch x86_64"
        unset LDSHARED
        # Force rebuild of all libs
        rm *-stamp
        pre_build
        # Build wheel
        export LDFLAGS="$LDFLAGS $py_ld_flags"
        export LDSHARED="clang $LDFLAGS $py_ld_flags"
        build_pip_wheel "$repo_dir"
        # Fuse into dual arch wheel(s)
        for whl in ${wheelhouse}/*.whl; do
            delocate-fuse "$whl" "${wheelhouse32}/$(basename $whl)"
        done
    }
fi

