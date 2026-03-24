include $(TOPDIR)/rules.mk

PKG_NAME:=hcxdumptool
PKG_VERSION:=6.3.4
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/ZerBea/hcxdumptool/archive/$(PKG_VERSION).tar.gz?
PKG_HASH:=skip
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk

define Package/hcxdumptool
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Small tool to capture packets from wlan devices
  URL:=https://github.com/ZerBea/hcxdumptool
  DEPENDS:=+libpcap +libopenssl +libnl-tiny
endef

define Package/hcxdumptool/description
  Tool to capture packets from WLAN devices for use with hashcat/john.
  Designed for use with external WiFi adapters in monitor mode.
  Supports active and passive PMKID/EAPOL capture.
endef

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR) \
		CC="$(TARGET_CC)" \
		CFLAGS="$(TARGET_CFLAGS) $(TARGET_CPPFLAGS) -I$(STAGING_DIR)/usr/include/libnl-tiny" \
		LDFLAGS="$(TARGET_LDFLAGS)" \
		PREFIX="/usr"
endef

define Package/hcxdumptool/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/hcxdumptool $(1)/usr/bin/
endef

$(eval $(call BuildPackage,hcxdumptool))
