
.PHONY: help get clean icons regen run run-ios run-macos \
        apk apk-all appbundle ios ipa macos windows linux \
        build-all package

PROJECT := .
DIST := dist

APK_UNIVERSAL_NAME := app-release.apk
AAB_NAME := app.aab
IPA_NAME := ios.ipa
IOS_APP_NAME := ios.app
MACOS_APP_NAME := mac.app
WINDOWS_DIR_NAME := windows
LINUX_DIR_NAME := linix

help:
	@echo "  get          — install dependencies"
	@echo "  clean        — clean and reinstall"
	@echo "  icons        — generate app icons"
	@echo "  regen        — run build_runner"
	@echo "  run          — run debug"
	@echo "  apk          — build APK"
	@echo "  apk-all      — build all APK types"
	@echo "  build-mobile — build for ios & android"
	@echo "  appbundle    — build AAB"
	@echo "  ios          — build iOS"
	@echo "  ipa          — build IPA"
	@echo "  macos        — build macOS"
	@echo "  windows      — build Windows"
	@echo "  linux        — build Linux"
	@echo "  build-all    — build everything"
	@echo "  package      — pack artifacts"

get:
	cd $(PROJECT) && flutter pub get

clean:
	cd $(PROJECT) && flutter clean && flutter pub get

icons:
	cd $(PROJECT) && dart run flutter_launcher_icons

regen:
	cd $(PROJECT) && dart run build_runner build --delete-conflicting-outputs

run:
	cd $(PROJECT) && flutter run

run-ios:
	cd $(PROJECT) && flutter run -d iphone

run-macos:
	cd $(PROJECT) && flutter run -d macos

apk:
	@mkdir -p $(DIST)
	cd $(PROJECT) && flutter build apk --release
	@cp -f $(PROJECT)/build/app/outputs/flutter-apk/app-release.apk \
		$(DIST)/$(APK_UNIVERSAL_NAME)

apk-all:
	@mkdir -p $(DIST)
	cd $(PROJECT) && flutter build apk --release --split-per-abi
	@for file in $(PROJECT)/build/app/outputs/flutter-apk/*-release.apk; do \
		[ -f "$$file" ] || continue; \
		name=$$(basename "$$file"); \
		cp -f "$$file" "$(DIST)/$$name"; \
	done



appbundle:
	@mkdir -p $(DIST)
	cd $(PROJECT) && flutter build appbundle --release
	@cp -f $(PROJECT)/build/app/outputs/bundle/release/app-release.aab \
		$(DIST)/$(AAB_NAME)



ios:
	@mkdir -p $(DIST)
	cd $(PROJECT) && flutter build ios --release --no-codesign
	@rm -rf "$(DIST)/$(IOS_APP_NAME)"
	@cp -r "$(PROJECT)/build/ios/iphoneos/Runner.app" \
		"$(DIST)/$(IOS_APP_NAME)"



ipa:
	@mkdir -p $(DIST)
	cd $(PROJECT) && flutter build ios --release --no-codesign

	@rm -rf $(PROJECT)/build/ios/ipa_tmp
	@mkdir -p $(PROJECT)/build/ios/ipa_tmp/Payload

	@cp -r $(PROJECT)/build/ios/iphoneos/Runner.app \
		$(PROJECT)/build/ios/ipa_tmp/Payload/

	@cd $(PROJECT)/build/ios/ipa_tmp && \
		zip -r -q $(IPA_NAME) Payload

	@cp -f $(PROJECT)/build/ios/ipa_tmp/$(IPA_NAME) \
		$(DIST)/$(IPA_NAME)

	@rm -rf $(PROJECT)/build/ios/ipa_tmp


macos:
	@mkdir -p $(DIST)
	cd $(PROJECT) && flutter build macos --release
	@rm -rf "$(DIST)/$(MACOS_APP_NAME)"
	@cp -r "$(PROJECT)/build/macos/Build/Products/Release/"*.app \
		"$(DIST)/$(MACOS_APP_NAME)"


windows:
	@mkdir -p $(DIST)
	cd $(PROJECT) && flutter build windows --release
	@rm -rf "$(DIST)/$(WINDOWS_DIR_NAME)"
	@cp -r "$(PROJECT)/build/windows/x64/runner/Release" \
		"$(DIST)/$(WINDOWS_DIR_NAME)"


linux:
	@mkdir -p $(DIST)
	cd $(PROJECT) && flutter build linux --release
	@rm -rf "$(DIST)/$(LINUX_DIR_NAME)"
	@cp -r "$(PROJECT)/build/linux/x64/release/bundle" \
		"$(DIST)/$(LINUX_DIR_NAME)"



build-all: icons regen apk appbundle ipa macos windows linux

build-mobile: icons regen apk-all ipa

package:
	@mkdir -p $(DIST)
	@tar -czf $(DIST)/artifacts.tar.gz \
		-C $(DIST) . \
		--exclude=artifacts.tar.gz

