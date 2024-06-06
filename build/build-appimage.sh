#!/bin/bash

APP_NAME="sinfo"
VERSION="$1"
ARCH="$2"
OUTPUT_DIR="dist"

if [ -z "$VERSION" ]; then
    VERSION="latest"
fi

if [ -z "$ARCH" ]; then
    ARCH="amd64"
fi


# 清理旧的构建目录
rm -rf $OUTPUT_DIR
mkdir -p $OUTPUT_DIR/AppDir/etc/sysinfokeeper
mkdir -p $OUTPUT_DIR/AppDir/etc/systemd/system
mkdir -p $OUTPUT_DIR/AppDir/usr/local/bin

# 编译二进制文件
echo "Building $APP_NAME $VERSION..."
env GOOS=linux GOARCH=$ARCH go build -o $OUTPUT_DIR/AppDir/usr/local/bin/$APP_NAME

# 复制配置文件
cp configs/comfig.toml $OUTPUT_DIR/AppDir/etc/sysinfokeeper/config

# 复制服务文件
cp deployments/$APP_NAME.service $OUTPUT_DIR/AppDir/etc/systemd/system/$APP_NAME.service

# 创建 AppImage
echo "Creating AppImage..."
appimagetool $OUTPUT_DIR/AppDir $OUTPUT_DIR/$APP_NAME-$VERSION-x86_64.AppImage

echo "AppImage created at $OUTPUT_DIR/$APP_NAME-$VERSION-x86_64.AppImage"
