#!/bin/sh


D=$(cd $(dirname $0);pwd)

# HueのSDKへのパス
HUE_FRAMEWORK="HueSDK_iOS.framework"
HUE_SDK=$D"/dConnectDeviceHue/"$HUE_FRAMEWORK

# GitHubからのダウンロード設定
HUE_CORE_URL="https://github.com/PhilipsHue/PhilipsHueSDK-iOS-OSX/archive/master.zip"
HUE_MASTER="PhilipsHueSDK-iOS-OSX-master"
HUE_ZIP_FILE=$HUE_MASTER".zip"

# Hueのダウンロード確認
if [ -e $HUE_SDK ]; then
    echo "hue sdk is exist."
else
    # hue sdkが存在しない場合には終了
    echo "hue sdk is not exist."
    echo ""
    echo "HueSDKダウンロードページより、ダウンロード。"
    echo "https://github.com/PhilipsHue/PhilipsHueSDK-iOS-OSX/"

    cd $D

    if [ -e $HUE_ZIP_FILE ]; then
        echo $HUE_FRAMEWORK" is exist."
    else
        curl -o $HUE_ZIP_FILE -LOk $HUE_CORE_URL
    fi

    unzip $HUE_ZIP_FILE
    mv $D"/"$HUE_MASTER"/"$HUE_FRAMEWORK $D
    rm -rf $D"/"$HUE_MASTER
    rm -rf $D"/"$HUE_ZIP_FILE
fi