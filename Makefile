APP_NAME := sinfo
OUTPUT_DIR := dist

.PHONY: all build push clean

VERSION ?= latest
ARCH ?= amd64
@source .minio.env

all: build push

build:
	@echo "Building $(APP_NAME) $(VERSION) for $(ARCH)..."
	@./tools/build-appimage.sh $(VERSION) $(ARCH)

push:
	@echo "Pushing $(APP_NAME)-$(VERSION)-$(ARCH).AppImage to MinIO..."
	mc alias set minio $(MINIO_ENDPOINT) $(MINIO_ACCESS_KEY) $(MINIO_SECRET_KEY)
	mc mb minio/$(MINIO_BUCKET)
	mc cp $(OUTPUT_DIR)/$(APP_NAME)-$(VERSION)-$(ARCH).AppImage minio/$(MINIO_BUCKET)/app/

clean:
	@echo "Cleaning up..."
	@rm -rf $(OUTPUT_DIR)
