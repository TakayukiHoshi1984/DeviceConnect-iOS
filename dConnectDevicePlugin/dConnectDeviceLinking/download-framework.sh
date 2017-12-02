#!/bin/sh


D=$(cd $(dirname $0);pwd)

# LinkingのSDKへのパス
LINKING_FRAMEWORK="LinkingLibrary.framework"
LINKING_SDK=$D"/dConnectDeviceLinking/Libs/Release/"$Linking_FRAMEWORK

# GitHubからのダウンロード設定
LINKING_CORE_URL="https://linkingiot.com/developer/zip/LinkingiOS_SDK.zip"
LINKING_MASTER="LinkingiOS_SDK"
LINKING_ZIP_FILE=$LINKING_MASTER".zip"
LINKING_RELEASE_ZIP_FILE="Release.zip"
# Linkingのダウンロード確認
if [ -e $LINKING_SDK ]; then
    echo "Linking sdk is exist."
else
    # Linking sdkが存在しない場合には終了
    echo "Linking sdk is not exist."
    echo ""
    echo "LinkingSDKダウンロードページより、ダウンロード。"
    echo "https://github.com/PhilipsLinking/PhilipsLinkingSDK-iOS-OSX/"

    cd $D

    if [ -e $LINKING_ZIP_FILE ]; then
        echo $LINKING_FRAMEWORK" is exist."
    else
        curl -o $LINKING_ZIP_FILE -LOk $LINKING_CORE_URL
    fi

    unzip $LINKING_ZIP_FILE
    unzip $LINKING_MASTER"/"$LINKING_RELEASE_ZIP_FILE

    mv $D"/"$LINKING_MASTER"/Release/Release/"$LINKING_FRAMEWORK $D"/Libs/Release"
    rm -rf $D"/"$LINKING_MASTER
    rm -rf $D"/Release"
    rm -rf $D"/"$LINKING_ZIP_FILE
fi