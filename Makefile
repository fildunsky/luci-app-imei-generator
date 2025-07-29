# Copyright 2025 Fil Dunsky
# Licensed under the GNU General Public License v2

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-imei-generator
PKG_VERSION:=1
PKG_RELEASE:=2

PKG_MAINTAINER:=Fil Dunsky <filipp.dunsky@gmail.com>

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=IMEI Generator for LuCI
  DEPENDS:=+luci-base +atinout
  PKGARCH:=all
endef

define Package/$(PKG_NAME)/description
  LuCI interface to generate phone IMEI for modem
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(CP) ./files/* $(1)/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))

