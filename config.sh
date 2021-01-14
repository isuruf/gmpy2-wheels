function build_simple2 {
    local name=$1
    local version=$2
    local url=$3
    local ext=$4
    shift 4
    if [ -e "${name}-stamp" ]; then
        return
    fi
    local name_version="${name}-${version}"
    local targz=${name_version}.$ext
    fetch_unpack $url/$targz
    (cd $name_version \
        && ((./configure --prefix=$BUILD_PREFIX $*) || (cat config.log && exit 1))  \
        && make \
        && make install)
    touch "${name}-stamp"
}

function pre_build {
    set -x
    if [[ "$PLAT" == "arm64" ]]; then
        # gmp has a custom configure script that doesn't use host_alias
        # mpfr, mpc don't need this
        configure_options="--host=$host_alias"
    fi
    build_simple2 gmp  6.2.1 https://gmplib.org/download/gmp tar.bz2 \
        --disable-shared --enable-static --with-pic --enable-fat $configure_options
    build_simple2 mpfr 4.1.0 http://ftp.gnu.org/gnu/mpfr tar.gz     \
        --disable-shared --enable-static --with-pic --with-gmp=$BUILD_PREFIX --disable-thread-safe --enable-gmp-internals
    build_simple2 mpc  1.2.1 https://ftp.gnu.org/gnu/mpc tar.gz \
        --disable-shared --enable-static --with-pic --with-gmp=$BUILD_PREFIX --with-mpfr=$BUILD_PREFIX
}

function run_tests {
    # Runs tests on installed distribution from an empty directory
    python --version
    python -c "import gmpy2"
}

