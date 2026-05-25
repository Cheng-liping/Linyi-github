TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = WeChat
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = quarkd

quarkd_FILES = Tweak.m QuarkAPI.m
quarkd_CFLAGS = -fobjc-arc -I. -Wno-nullability-completeness
quarkd_FRAMEWORKS = Foundation UIKit
quarkd_PRIVATE_FRAMEWORKS = AppSupport
quarkd_LIBRARIES = MobileSubstrate

include $(THEOS_MAKE_PATH)/tweak.mk
