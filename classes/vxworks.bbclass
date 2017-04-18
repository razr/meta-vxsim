inherit vxworks-kernel-base

PROVIDES += "virtual/kernel"
DEPENDS += "virtual/${TARGET_PREFIX}libc tcl-native"

S = "${STAGING_KERNEL_DIR}"
B = "${WORKDIR}/build"
KBUILD_OUTPUT = "${B}"
OE_TERMINAL_EXPORTS += "KBUILD_OUTPUT"

KERNEL_IMAGETYPE ?= "vxWorks"
INITRAMFS_IMAGE ?= ""
INITRAMFS_TASK ?= ""
INITRAMFS_IMAGE_BUNDLE ?= ""

# KERNEL_VERSION is extracted from source code. It is evaluated as
# None for the first parsing, since the code has not been fetched.
# After the code is fetched, it will be evaluated as real version
# number and cause kernel to be rebuilt. To avoid this, make
# KERNEL_VERSION_NAME and KERNEL_VERSION_PKG_NAME depend on
# LINUX_VERSION which is a constant.
KERNEL_VERSION_NAME = "${@d.getVar('KERNEL_VERSION') or ""}"
KERNEL_VERSION_NAME[vardepvalue] = "${VXWORKS_VERSION}"
KERNEL_VERSION_PKG_NAME = "${@legitimize_package_name(d.getVar('KERNEL_VERSION'))}"
KERNEL_VERSION_PKG_NAME[vardepvalue] = "${VXWORKS_VERSION}"


do_unpack[cleandirs] += " ${S} ${STAGING_KERNEL_DIR} ${B} ${STAGING_KERNEL_BUILDDIR}"
do_clean[cleandirs] += " ${S} ${STAGING_KERNEL_DIR} ${B} ${STAGING_KERNEL_BUILDDIR}"

inherit kernel-arch deploy

PACKAGES_DYNAMIC += "^kernel-image-.*"

export OS = "${TARGET_OS}"
export CROSS_COMPILE = "${TARGET_PREFIX}"

KERNEL_RELEASE ?= "${KERNEL_VERSION}"

# The directory where built kernel lies in the kernel tree
KERNEL_OUTPUT_DIR ?= "arch/${ARCH}/boot"
KERNEL_IMAGEDEST = "boot"

#
# configuration
#
export CMDLINE_CONSOLE = "console=${@d.getVar("KERNEL_CONSOLE") or "ttyS0"}"

KERNEL_VERSION = "${@get_kernelversion_headers('${B}')}"

KERNEL_LOCALVERSION ?= ""

# kernels are generally machine specific
PACKAGE_ARCH = "${MACHINE_ARCH}"

# Some Linux kernel configurations need additional parameters on the command line
KERNEL_EXTRA_ARGS ?= ""

EXTRA_OEMAKE = " HOSTCC="${BUILD_CC}" HOSTCPP="${BUILD_CPP}""

python do_devshell_prepend () {
    os.environ["LDFLAGS"] = ''
}

addtask bundle_initramfs after do_install before do_deploy

kernel_do_compile() {

}

kernel_do_install() {

}

do_install[prefuncs] += "package_get_auto_pr"

# Must be ran no earlier than after do_kernel_checkout or else Makefile won't be in ${S}/Makefile
do_kernel_version_sanity_check() {

}


# We don't need to stage anything
sysroot_stage_all () {
	:
}

kernel_do_configure() {

}


inherit cml1

EXPORT_FUNCTIONS do_compile do_install do_configure

# kernel-base becomes kernel-${KERNEL_VERSION}
# kernel-image becomes kernel-image-${KERNEL_VERSION}
PACKAGES = "kernel kernel-base kernel-vmlinux kernel-image kernel-dev kernel-modules"
FILES_${PN} = ""
FILES_kernel-base = "${nonarch_base_libdir}/modules/${KERNEL_VERSION}/modules.order ${nonarch_base_libdir}/modules/${KERNEL_VERSION}/modules.builtin"
FILES_kernel-image = ""
FILES_kernel-dev = "/boot/System.map* /boot/Module.symvers* /boot/config* ${KERNEL_SRC_PATH} ${nonarch_base_libdir}/modules/${KERNEL_VERSION}/build"
FILES_kernel-vmlinux = "/boot/vmlinux-${KERNEL_VERSION_NAME}"
FILES_kernel-modules = ""
RDEPENDS_kernel = "kernel-base"
# Allow machines to override this dependency if kernel image files are
# not wanted in images as standard
RDEPENDS_kernel-base ?= "kernel-image"
PKG_kernel-image = "kernel-image-${@legitimize_package_name('${KERNEL_VERSION}')}"
RDEPENDS_kernel-image += "${@base_conditional('KERNEL_IMAGETYPE', 'vmlinux', 'kernel-vmlinux', '', d)}"
PKG_kernel-base = "kernel-${@legitimize_package_name('${KERNEL_VERSION}')}"
RPROVIDES_kernel-base += "kernel-${KERNEL_VERSION}"
ALLOW_EMPTY_kernel = "1"
ALLOW_EMPTY_kernel-base = "1"
ALLOW_EMPTY_kernel-image = "1"
ALLOW_EMPTY_kernel-modules = "1"
DESCRIPTION_kernel-modules = "Kernel modules meta package"

pkg_postinst_kernel-base () {
	if [ ! -e "$D/lib/modules/${KERNEL_VERSION}" ]; then
		mkdir -p $D/lib/modules/${KERNEL_VERSION}
	fi
	if [ -n "$D" ]; then
		depmodwrapper -a -b $D ${KERNEL_VERSION}
	else
		depmod -a ${KERNEL_VERSION}
	fi
}

PACKAGESPLITFUNCS_prepend = "split_kernel_packages "

python split_kernel_packages () {
    do_split_packages(d, root='${nonarch_base_libdir}/firmware', file_regex='^(.*)\.(bin|fw|cis|csp|dsp)$', output_pattern='kernel-firmware-%s', description='Firmware for %s', recursive=True, extra_depends='')
}

# Many scripts want to look in arch/$arch/boot for the bootable
# image. This poses a problem for vmlinux and vmlinuz based
# booting. This task arranges to have vmlinux and vmlinuz appear
# in the normalized directory location.
do_kernel_link_images() {
	if [ ! -d "${B}/arch/${ARCH}/boot" ]; then
		mkdir ${B}/arch/${ARCH}/boot
	fi
	cd ${B}/arch/${ARCH}/boot
	ln -sf ../../../vmlinux
	if [ -f ../../../vmlinuz ]; then
		ln -sf ../../../vmlinuz
	fi
	if [ -f ../../../vmlinuz.bin ]; then
		ln -sf ../../../vmlinuz.bin
	fi
}

do_strip() {
	if [ -n "${KERNEL_IMAGE_STRIP_EXTRA_SECTIONS}" ]; then
		if ! (echo "${KERNEL_IMAGETYPES}" | grep -wq "vmlinux"); then
			bbwarn "image type(s) will not be stripped (not supported): ${KERNEL_IMAGETYPES}"
			return
		fi

		cd ${B}
		headers=`"$CROSS_COMPILE"readelf -S ${KERNEL_OUTPUT_DIR}/vmlinux | \
			  grep "^ \{1,\}\[[0-9 ]\{1,\}\] [^ ]" | \
			  sed "s/^ \{1,\}\[[0-9 ]\{1,\}\] //" | \
			  gawk '{print $1}'`

		for str in ${KERNEL_IMAGE_STRIP_EXTRA_SECTIONS}; do {
			if ! (echo "$headers" | grep -q "^$str$"); then
				bbwarn "Section not found: $str";
			fi

			"$CROSS_COMPILE"strip -s -R $str ${KERNEL_OUTPUT_DIR}/vmlinux
		}; done

		bbnote "KERNEL_IMAGE_STRIP_EXTRA_SECTIONS is set, stripping sections:" \
			"${KERNEL_IMAGE_STRIP_EXTRA_SECTIONS}"
	fi;
}
do_strip[dirs] = "${B}"

addtask do_strip before do_sizecheck after do_kernel_link_images

# Support checking the kernel size since some kernels need to reside in partitions
# with a fixed length or there is a limit in transferring the kernel to memory
do_sizecheck() {
	if [ ! -z "${KERNEL_IMAGE_MAXSIZE}" ]; then
		invalid=`echo ${KERNEL_IMAGE_MAXSIZE} | sed 's/[0-9]//g'`
		if [ -n "$invalid" ]; then
			die "Invalid KERNEL_IMAGE_MAXSIZE: ${KERNEL_IMAGE_MAXSIZE}, should be an integerx (The unit is Kbytes)"
		fi
		for type in ${KERNEL_IMAGETYPES} ; do
			size=`du -ks ${B}/${KERNEL_OUTPUT_DIR}/$type | awk '{print $1}'`
			if [ $size -ge ${KERNEL_IMAGE_MAXSIZE} ]; then
				warn "This kernel $type (size=$size(K) > ${KERNEL_IMAGE_MAXSIZE}(K)) is too big for your device. Please reduce the size of the kernel by making more of it modular."
			fi
		done
	fi
}
do_sizecheck[dirs] = "${B}"

addtask sizecheck before do_install after do_strip

KERNEL_IMAGE_BASE_NAME ?= "${PKGE}-${PKGV}-${PKGR}-${MACHINE}-${DATETIME}"
# Don't include the DATETIME variable in the sstate package signatures
KERNEL_IMAGE_BASE_NAME[vardepsexclude] = "DATETIME"
KERNEL_IMAGE_SYMLINK_NAME ?= "${MACHINE}"
MODULE_IMAGE_BASE_NAME ?= "modules-${PKGE}-${PKGV}-${PKGR}-${MACHINE}-${DATETIME}"
MODULE_IMAGE_BASE_NAME[vardepsexclude] = "DATETIME"
MODULE_TARBALL_BASE_NAME ?= "${MODULE_IMAGE_BASE_NAME}.tgz"
# Don't include the DATETIME variable in the sstate package signatures
MODULE_TARBALL_SYMLINK_NAME ?= "modules-${MACHINE}.tgz"
MODULE_TARBALL_DEPLOY ?= "1"

kernel_do_deploy() {
	for type in ${KERNEL_IMAGETYPES} ; do
		base_name=${type}-${KERNEL_IMAGE_BASE_NAME}
		install -m 0644 ${KERNEL_OUTPUT_DIR}/${type} ${DEPLOYDIR}/${base_name}.bin
	done
	if [ ${MODULE_TARBALL_DEPLOY} = "1" ] && (grep -q -i -e '^CONFIG_MODULES=y$' .config); then
		mkdir -p ${D}/lib
		tar -cvzf ${DEPLOYDIR}/${MODULE_TARBALL_BASE_NAME} -C ${D} lib
		ln -sf ${MODULE_TARBALL_BASE_NAME} ${DEPLOYDIR}/${MODULE_TARBALL_SYMLINK_NAME}
	fi

	for type in ${KERNEL_IMAGETYPES} ; do
		base_name=${type}-${KERNEL_IMAGE_BASE_NAME}
		symlink_name=${type}-${KERNEL_IMAGE_SYMLINK_NAME}
		ln -sf ${base_name}.bin ${DEPLOYDIR}/${symlink_name}.bin
		ln -sf ${base_name}.bin ${DEPLOYDIR}/${type}
	done

	cd ${B}
	# Update deploy directory
	for type in ${KERNEL_IMAGETYPES} ; do
		if [ -e "${KERNEL_OUTPUT_DIR}/${type}.initramfs" ]; then
			echo "Copying deploy ${type} kernel-initramfs image and setting up links..."
			initramfs_base_name=${type}-${INITRAMFS_BASE_NAME}
			initramfs_symlink_name=${type}-initramfs-${MACHINE}
			install -m 0644 ${KERNEL_OUTPUT_DIR}/${type}.initramfs ${DEPLOYDIR}/${initramfs_base_name}.bin
			ln -sf ${initramfs_base_name}.bin ${DEPLOYDIR}/${initramfs_symlink_name}.bin
		fi
	done
}
do_deploy[cleandirs] = "${DEPLOYDIR}"
do_deploy[dirs] = "${DEPLOYDIR} ${B}"
do_deploy[prefuncs] += "package_get_auto_pr"

addtask deploy after do_populate_sysroot do_packagedata

EXPORT_FUNCTIONS do_deploy
