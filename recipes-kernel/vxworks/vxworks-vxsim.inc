require vxworks-sim.inc

DESCRIPTION = "VxWorks Kernel for VxSim"
SECTION = "kernel"
LICENSE = "GPLv2"
LIC_FILES_CHKSUM = "file://COPYING;md5=d7810fab7487fb0aad327b76f1be7cd7"

COMPATIBLE_MACHINE = "vxsim"

PE = "1"
PV = "${VXWORKS_VERSION}"

# CMDLINE for vxsim
CMDLINE = "ei(0,0)host:/usr/vw/config/bsp/vxWorks h=90.0.0.3 e=90.0.0.50 u=target"

