# Source library for shell script tests
#
# Copyright (C) 2011 Colin Walters <walters@verbum.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the
# Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.

# Have we already been sourced?
if test -n "${LIBTEST_SH:-}"; then
  # would be good to know when it happens
  echo "INFO: Skipping subsequent sourcing of libtest.sh"
  return
fi
LIBTEST_SH=1

self="$(realpath $0)"

for bin in jq; do
    if ! command -v $bin >/dev/null; then
        (echo ${bin} is required to execute tests 1>&2; exit 1)
    fi
done

if test -z "${SRCDIR:-}"; then
    SRCDIR=${topsrcdir}/tests
fi

_cleanup_tmpdir () {
    if test -z "${TEST_SKIP_CLEANUP:-}"; then
	if test -f ${test_tmpdir}/.test; then
           rm ${test_tmpdir} -rf
	fi
    else
	echo "Skipping cleanup of ${test_tmpdir}"
    fi
}

# Create a tmpdir if we're running as a local test (i.e. through `make check`)
# or as a `vmcheck` test, which also needs some scratch space on the host.
if ( test -n "${UNINSTALLEDTESTS:-}" || test -n "${VMTESTS:-}" ) && ! test -f $PWD/.test; then
   test_tmpdir=$(mktemp -d test.XXXXXX)
   touch ${test_tmpdir}/.test
   trap _cleanup_tmpdir EXIT
   cd ${test_tmpdir}
fi
if test -n "${UNINSTALLEDTESTS:-}"; then
    export PATH=${builddir}:${PATH}
fi

test_tmpdir=$(pwd)
echo "Using tmpdir ${test_tmpdir}"

export G_DEBUG=fatal-warnings

# Don't flag deployments as immutable so that test harnesses can
# easily clean up.
export OSTREE_SYSROOT_DEBUG=mutable-deployments

export TEST_GPG_KEYID="472CDAFA"

# GPG when creating signatures demands a writable
# homedir in order to create lockfiles.  Work around
# this by copying locally.
echo "Copying gpghome to ${test_tmpdir}"
cp -a "${SRCDIR}/gpghome" ${test_tmpdir}
chmod -R u+w "${test_tmpdir}"
export TEST_GPG_KEYHOME=${test_tmpdir}/gpghome
export OSTREE_GPG_HOME=${test_tmpdir}/gpghome/trusted

if test -n "${OT_TESTS_DEBUG:-}"; then
    set -x
fi

if test -n "${OT_TESTS_VALGRIND:-}"; then
    CMD_PREFIX="env G_SLICE=always-malloc valgrind -q --leak-check=full --num-callers=30 --suppressions=${SRCDIR}/ostree-valgrind.supp"
fi

assert_not_reached () {
    echo $@ 1>&2; exit 1
}

assert_streq () {
    test "$1" = "$2" || (echo 1>&2 "$1 != $2"; exit 1)
}

assert_not_streq () {
    (! test "$1" = "$2") || (echo 1>&2 "$1 == $2"; exit 1)
}

assert_has_file () {
    test -f "$1" || (echo 1>&2 "Couldn't find '$1'"; exit 1)
}

assert_has_dir () {
    test -d "$1" || (echo 1>&2 "Couldn't find '$1'"; exit 1)
}

assert_not_has_file () {
    if test -f "$1"; then
        sed -e 's/^/# /' < "$1" >&2
        echo 1>&2 "File '$1' exists"
        exit 1
    fi
}

assert_not_file_has_content () {
    if grep -q -e "$2" "$1"; then
        sed -e 's/^/# /' < "$1" >&2
        echo 1>&2 "File '$1' incorrectly matches regexp '$2'"
        exit 1
    fi
}

assert_not_has_dir () {
    if test -d "$1"; then
	echo 1>&2 "Directory '$1' exists"; exit 1
    fi
}

assert_file_has_content () {
    if ! grep -q -e "$2" "$1"; then
        sed -e 's/^/# /' < "$1" >&2
        echo 1>&2 "File '$1' doesn't match regexp '$2'"
        exit 1
    fi
}

assert_file_empty() {
    if test -s "$1"; then
        sed -e 's/^/# /' < "$1" >&2
        echo 1>&2 "File '$1' is not empty"
        exit 1
    fi
}

setup_test_repository () {
    mode=$1
    shift

    oldpwd=`pwd`

    cd ${test_tmpdir}
    mkdir repo
    cd repo
    ot_repo="--repo=`pwd`"
    export OSTREE="${CMD_PREFIX} ostree ${ot_repo}"
    if test -n "$mode"; then
	$OSTREE init --mode=${mode}
    else
	$OSTREE init
    fi

    cd ${test_tmpdir}
    mkdir files
    cd files
    ot_files=`pwd`
    export ht_files
    ln -s nosuchfile somelink
    echo first > firstfile

    cd ${test_tmpdir}/files
    $OSTREE commit -b test2 -s "Test Commit 1" -m "Commit body first"

    mkdir baz
    echo moo > baz/cow
    echo alien > baz/saucer
    mkdir baz/deeper
    echo hi > baz/deeper/ohyeah
    ln -s nonexistent baz/alink
    mkdir baz/another/
    echo x > baz/another/y

    cd ${test_tmpdir}/files
    $OSTREE commit -b test2 -s "Test Commit 2" -m "Commit body second"
    $OSTREE fsck -q

    cd $oldpwd
}

setup_fake_remote_repo1() {
    mode=$1
    args=$2
    shift
    oldpwd=`pwd`
    mkdir ostree-srv
    cd ostree-srv
    mkdir gnomerepo
    ${CMD_PREFIX} ostree --repo=gnomerepo init --mode=$mode
    mkdir gnomerepo-files
    cd gnomerepo-files 
    echo first > firstfile
    mkdir baz
    echo moo > baz/cow
    echo alien > baz/saucer
    ${CMD_PREFIX} ostree  --repo=${test_tmpdir}/ostree-srv/gnomerepo commit --add-metadata-string version=3.0 -b main -s "A remote commit" -m "Some Commit body"
    mkdir baz/deeper
    ${CMD_PREFIX} ostree --repo=${test_tmpdir}/ostree-srv/gnomerepo commit --add-metadata-string version=3.1 -b main -s "Add deeper"
    echo hi > baz/deeper/ohyeah
    mkdir baz/another/
    echo x > baz/another/y
    ${CMD_PREFIX} ostree --repo=${test_tmpdir}/ostree-srv/gnomerepo commit --add-metadata-string version=3.2 -b main -s "The rest"
    cd ..
    rm -rf gnomerepo-files
    
    cd ${test_tmpdir}
    mkdir ${test_tmpdir}/httpd
    cd httpd
    ln -s ${test_tmpdir}/ostree-srv ostree
    ostree trivial-httpd --autoexit --daemonize -p ${test_tmpdir}/httpd-port $args
    port=$(cat ${test_tmpdir}/httpd-port)
    echo "http://127.0.0.1:${port}" > ${test_tmpdir}/httpd-address
    cd ${oldpwd} 

    export OSTREE="ostree --repo=repo"
}

setup_os_boot_syslinux() {
    # Stub syslinux configuration
    mkdir -p sysroot/boot/loader.0
    ln -s loader.0 sysroot/boot/loader
    touch sysroot/boot/loader/syslinux.cfg
    # And a compatibility symlink
    mkdir -p sysroot/boot/syslinux
    ln -s ../loader/syslinux.cfg sysroot/boot/syslinux/syslinux.cfg
}

setup_os_boot_uboot() {
    # Stub U-Boot configuration
    mkdir -p sysroot/boot/loader.0
    ln -s loader.0 sysroot/boot/loader
    touch sysroot/boot/loader/uEnv.txt
    # And a compatibility symlink
    ln -s loader/uEnv.txt sysroot/boot/uEnv.txt
}

setup_os_repository () {
    mode=$1
    bootmode=$2
    shift

    oldpwd=`pwd`

    cd ${test_tmpdir}
    mkdir testos-repo
    if test -n "$mode"; then
	ostree --repo=testos-repo init --mode=${mode}
    else
	ostree --repo=testos-repo init
    fi

    cd ${test_tmpdir}
    mkdir osdata
    cd osdata
    mkdir -p boot usr/bin usr/lib/modules/3.6.0 usr/share usr/etc
    echo "a kernel" > boot/vmlinuz-3.6.0
    echo "an initramfs" > boot/initramfs-3.6.0
    bootcsum=$(cat boot/vmlinuz-3.6.0 boot/initramfs-3.6.0 | sha256sum | cut -f 1 -d ' ')
    export bootcsum
    mv boot/vmlinuz-3.6.0 boot/vmlinuz-3.6.0-${bootcsum}
    mv boot/initramfs-3.6.0 boot/initramfs-3.6.0-${bootcsum}
    
    echo "an executable" > usr/bin/sh
    echo "some shared data" > usr/share/langs.txt
    echo "a library" > usr/lib/libfoo.so.0
    ln -s usr/bin bin
cat > usr/etc/os-release <<EOF
NAME=TestOS
VERSION=42
ID=testos
VERSION_ID=42
PRETTY_NAME="TestOS 42"
EOF
    echo "a config file" > usr/etc/aconfigfile
    mkdir -p usr/etc/NetworkManager
    echo "a default daemon file" > usr/etc/NetworkManager/nm.conf
    mkdir -p usr/etc/testdirectory
    echo "a default daemon file" > usr/etc/testdirectory/test

    ostree --repo=${test_tmpdir}/testos-repo commit --add-metadata-string version=1.0.9 -b testos/buildmaster/x86_64-runtime -s "Build"
    
    # Ensure these commits have distinct second timestamps
    sleep 2
    echo "a new executable" > usr/bin/sh
    ostree --repo=${test_tmpdir}/testos-repo commit --add-metadata-string version=1.0.10 -b testos/buildmaster/x86_64-runtime -s "Build"

    cd ${test_tmpdir}
    cp -a osdata osdata-devel
    cd osdata-devel
    mkdir -p usr/include
    echo "a development header" > usr/include/foo.h
    ostree --repo=${test_tmpdir}/testos-repo commit --add-metadata-string version=1.0.9 -b testos/buildmaster/x86_64-devel -s "Build"

    ostree --repo=${test_tmpdir}/testos-repo fsck -q

    cd ${test_tmpdir}
    # sysroot dir already made by setup-session.sh
    ostree admin --sysroot=sysroot init-fs sysroot
    ostree admin --sysroot=sysroot os-init testos

    case $bootmode in
        "syslinux")
	    setup_os_boot_syslinux
            ;;
        "uboot")
	    setup_os_boot_uboot
            ;;
    esac
    
    cd ${test_tmpdir}
    mkdir ${test_tmpdir}/httpd
    cd httpd
    ln -s ${test_tmpdir} ostree
    ostree trivial-httpd --autoexit --daemonize -p ${test_tmpdir}/httpd-port $args
    port=$(cat ${test_tmpdir}/httpd-port)
    echo "http://127.0.0.1:${port}" > ${test_tmpdir}/httpd-address
    cd ${oldpwd} 
}

os_repository_new_commit ()
{
    boot_checksum_iteration=$1
    content_iteration=$2
    echo "BOOT ITERATION: $boot_checksum_iteration"
    if test -z "$boot_checksum_iteration"; then
	boot_checksum_iteration=0
    fi
    if test -z "$content_iteration"; then
	content_iteration=0
    fi
    cd ${test_tmpdir}/osdata
    rm boot/*
    echo "new: a kernel ${boot_checksum_iteration}" > boot/vmlinuz-3.6.0
    echo "new: an initramfs ${boot_checksum_iteration}" > boot/initramfs-3.6.0
    bootcsum=$(cat boot/vmlinuz-3.6.0 boot/initramfs-3.6.0 | sha256sum | cut -f 1 -d ' ')
    export bootcsum
    mv boot/vmlinuz-3.6.0 boot/vmlinuz-3.6.0-${bootcsum}
    mv boot/initramfs-3.6.0 boot/initramfs-3.6.0-${bootcsum}

    echo "a new default config file" > usr/etc/a-new-default-config-file
    mkdir -p usr/etc/new-default-dir
    echo "a new default dir and file" > usr/etc/new-default-dir/moo

    echo "content iteration ${content_iteration}" > usr/bin/content-iteration

    version=$(date "+%Y%m%d.${content_iteration}")
    echo "version: $version"

    ostree --repo=${test_tmpdir}/testos-repo commit  --add-metadata-string "version=${version}" -b testos/buildmaster/x86_64-runtime -s "Build"
    cd ${test_tmpdir}
}

skip() {
    echo "1..0 # SKIP" "$@"
    exit 0
}

check_root_test ()
{
    if test "$(id -u)" != "0"; then
       skip "This test requires uid 0"
    fi
    if ! capsh --print | grep -q 'Bounding set.*[^a-z]cap_sys_admin'; then
        skip "No CAP_SYS_ADMIN in bounding set"
    fi
}

ensure_dbus ()
{
    if test -z "$RPMOSTREE_USE_SESSION_BUS"; then
        exec "$topsrcdir/tests/utils/setup-session.sh" "$self"
    fi
}

assert_status_file_jq() {
    status_file=$1; shift
    for expression in "$@"; do
        if ! jq -e "${expression}" >/dev/null < $status_file; then
            jq . < $status_file | sed -e 's/^/# /' >&2
            echo 1>&2 "${expression} failed to match in $status_file"
            exit 1
        fi
    done
}

assert_status_jq() {
    rpm-ostree status --json > status.json
    assert_status_file_jq status.json "$@"
}
