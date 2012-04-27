root.build/ignore-errors = bugzilla3

COMMON_CONF += postfix-local apache-credit apache-vhost

include $(FAB_PATH)/common/mk/turnkey/mysql.mk
include $(FAB_PATH)/common/mk/turnkey.mk
