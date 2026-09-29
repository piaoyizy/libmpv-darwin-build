project('libarchive-wrapper', 'c')

cmake = import('cmake')

cpu = host_machine.cpu()
if cpu == 'amd64'
    arch = 'x86_64'
elif cpu == 'arm64'
    arch = 'arm64'
endif

options = cmake.subproject_options()
options.add_cmake_defines({
    'CMAKE_OSX_ARCHITECTURES': arch,
    'CMAKE_OSX_SYSROOT': meson.get_cross_property('cmake_osx_sysroot'),
    'CMAKE_POSITION_INDEPENDENT_CODE': true,
    'CMAKE_C_COMPILER_WORKS': true,
    'BUILD_SHARED_LIBS': false,
    'ENABLE_INSTALL': false,
    'ENABLE_TEST': false,
    'ENABLE_TAR': false,
    'ENABLE_CPIO': false,
    'ENABLE_CAT': false,
    'ENABLE_MBEDTLS': false,
    'ENABLE_NETTLE': false,
    'ENABLE_OPENSSL': false,
    'ENABLE_LIBB2': false,
    'ENABLE_LZ4': false,
    'ENABLE_LZO': false,
    'ENABLE_LZMA': false,
    'ENABLE_ZSTD': false,
    'ENABLE_ZLIB': false,
    'ENABLE_BZip2': false,
    'ENABLE_LIBXML2': false,
    'ENABLE_EXPAT': false,
    'ENABLE_PCREPOSIX': false,
    'ENABLE_PCRE2POSIX': false,
    'ENABLE_LIBGCC': false,
    'POSIX_REGEX_LIB': 'NONE',
    'ENABLE_CNG': false,
    'ENABLE_ACL': false,
    'ENABLE_XATTR': false,
    'ENABLE_ICONV': false,
})

cmake.subproject('libarchive', options: options)
