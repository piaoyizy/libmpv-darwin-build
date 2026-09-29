project('libarchive-wrapper', 'c')

cmake = import('cmake')

cpu = host_machine.cpu()
if cpu == 'amd64'
    arch = 'x86_64'
elif cpu == 'arm64'
    arch = 'arm64'
endif

options = cmake.subproject_options()
apple_sysroot = meson.get_cross_property('cmake_osx_sysroot')
options.add_cmake_defines({
    'CMAKE_OSX_ARCHITECTURES': arch,
    'CMAKE_OSX_SYSROOT': apple_sysroot,
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

# CMake cannot infer iOS reliably from Meson's generic Darwin host machine.
# Without this, its feature checks omit the iOS target mode and even basic
# types such as pid_t appear to be unavailable.
if apple_sysroot.contains('iPhone')
    ios_deployment_target = '9.0'
    if apple_sysroot.contains('iPhoneSimulator') and arch == 'arm64'
        ios_deployment_target = '12.0'
    endif
    options.add_cmake_defines({
        'CMAKE_SYSTEM_NAME': 'iOS',
        'CMAKE_OSX_DEPLOYMENT_TARGET': ios_deployment_target,
    })
endif

cmake.subproject('libarchive', options: options)
