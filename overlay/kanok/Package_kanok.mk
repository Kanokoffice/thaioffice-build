# -*- Mode: makefile-gmake; tab-width: 4; indent-tabs-mode: t -*-
#
# KanokOffice (NALLTC Limited) · new file, not part of LibreOffice
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# share/registry/kanok.xcd: Thai defaults, read at first start (before extensions are synchronised)
# share/kanok/: default templates for new Writer and Calc documents (paths set in kanok.xcd)
#

$(eval $(call gb_Package_Package,kanok,$(SRCDIR)/kanok))

$(eval $(call gb_Package_add_file,kanok,$(LIBO_SHARE_FOLDER)/registry/kanok.xcd,registry/kanok.xcd))
$(eval $(call gb_Package_add_file,kanok,$(LIBO_SHARE_FOLDER)/kanok/thai-default.ott,template/thai-default.ott))
$(eval $(call gb_Package_add_file,kanok,$(LIBO_SHARE_FOLDER)/kanok/thai-default-calc.ots,template/thai-default-calc.ots))

# vim: set noet sw=4 ts=4:
