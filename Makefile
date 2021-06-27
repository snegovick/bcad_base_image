DIR_APPIMAGE=bcad.AppDir_t
BUILD_DIR=$(DIR_APPIMAGE)

$(BUILD_DIR)/usr:
	@echo "Creating build directories" && mkdir -p $(BUILD_DIR)/usr

.PHONY: build-baseimage
build-baseimage: $(BUILD_DIR)/usr
	@echo "Building baseimage"; bash ./packaging/build_baseimage.sh

.PHONY: clean
clean:
	rm -rf $(DIR_APPIMAGE)

.PHONY: dist-clean
dist-clean:
	rm -rf $(DIR_APPIMAGE)
	git clean -fd
