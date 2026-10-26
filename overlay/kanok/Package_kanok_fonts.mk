# -*- Mode: makefile-gmake; tab-width: 4; indent-tabs-mode: t -*-
#
# KanokOffice (NALLTC Limited) · new file, not part of LibreOffice
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# TH SarabunPSK 1.000 (DIP & SIPA), the font of the default templates, in every installer (MSI and .deb).
# share/fonts/truetype of the office, loaded by the office itself (on Windows: AddFontResourceEx FR_PRIVATE
# in vcl/win/gdi/salfont.cxx), not installed into the system font folder. Package list ooo (Repository.mk).
# The font files are included unmodified, as received (license terms 2-3; the Windows workflow checks
# their sha256 before building); only the file names have no spaces, because gbuild targets cannot
# hold them. The license is installed next to them (legal review F-3), unchanged (UTF-16, as published).
#

$(eval $(call gb_Package_Package,kanok_fonts,$(SRCDIR)/kanok/fonts))

$(eval $(call gb_Package_add_files,kanok_fonts,$(LIBO_SHARE_FOLDER)/fonts/truetype,\
	THSarabun.ttf \
	THSarabun-Bold.ttf \
	THSarabun-Italic.ttf \
	THSarabun-BoldItalic.ttf \
	DIP-SIPA-Font-License-Agreement.txt \
))

# vim: set noet sw=4 ts=4:
