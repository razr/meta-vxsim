FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}-${PV}:"

VXWORKS_VERSION ?= "7.0.0.0"

SRCREV = "095c4480e1f623bdc8a221a171ef13b2223706b1"
SRC_URI = "file://vxWorks-7.0.0.0.zip \
"
require vxworks-vxsim.inc
