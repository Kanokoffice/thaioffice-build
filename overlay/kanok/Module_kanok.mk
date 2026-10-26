# -*- Mode: makefile-gmake; tab-width: 4; indent-tabs-mode: t -*-
#
# KanokOffice (NALLTC Limited) · new file, not part of LibreOffice
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Thai defaults, default templates, bundled extensions and the TH SarabunPSK font shipped in every installer
# (MSI and .deb), so no step after installation is needed.
#

$(eval $(call gb_Module_Module,kanok))

$(eval $(call gb_Module_add_targets,kanok,\
	Package_kanok \
	Package_kanok_fonts \
	ExtensionPackage_kanok-bedate \
	ExtensionPackage_dict-th-thaioffice \
))

# vim: set noet sw=4 ts=4:
