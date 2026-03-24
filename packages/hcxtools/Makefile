include $(TOPDIR)/rules.mk

PKG_NAME:=hcxtools
PKG_VERSION:=6.3.4
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/ZerBea/hcxtools/archive/$(PKG_VERSION).tar.gz?
PKG_HASH:=skip
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk

define Package/hcxtools
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Tools to convert and process capture files
  URL:=https://github.com/ZerBea/hcxtools
  DEPENDS:=+libopenssl +libpcap +zlib
endef

define Package/hcxtools/description
  Set of tools to convert and filter capture files for use with
  hashcat/john. Includes hcxpcapngtool, hcxhashtool, hcxpmktool,
  and other utilities.
endef

MAKE_FLAGS += \
	PREFIX="/usr" \
	CFLAGS="$(TARGET_CFLAGS) $(TARGET_CPPFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)"

define Package/hcxtools/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/hcxpcapngtool $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/hcxhashtool $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/hcxpmktool $(1)/usr/bin/
endef

$(eval $(call BuildPackage,hcxtools))
