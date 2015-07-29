COMMON_OVERLAYS = apache
COMMON_CONF += apache-credit apache-vhost

include $(FAB_PATH)/common/mk/turnkey/mysql.mk
include $(FAB_PATH)/common/mk/turnkey.mk
