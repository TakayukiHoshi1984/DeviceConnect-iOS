#!/bin/bash


D=$(cd $(dirname $0);pwd)

# THETAのSDKへのパス
THETA_R_EXIF="lib-r-exif"
THETA_RICOH_THETA="lib-ricoh-theta"
THETA_RICOH_THETA_SERIALIZER="lib-ricoh-theta_serializer"
THETA_SDK=$D"/dConnectDeviceTheta/Classes/lib"

# GitHubからのダウンロード設定 TODO:Signature
THETA_CORE_URL="https://developers.theta360.com/downloads?filename=RICOH_THETA_SDK_for_iOS.0.3.0.zip"
THETA_MASTER="RICOH_THETA_SDK_for_iOS.0.3.0"
THETA_ZIP_FILE=$THETA_MASTER".zip"
# THETAのダウンロード確認
if [ -e $THETA_SDK ]; then
    echo "THETA sdk is exist."
else
    # THETA sdkが存在しない場合には終了
    echo "THETA sdk is not exist."
    echo ""
    echo "THETASDKダウンロードページより、ダウンロード。"
    echo "https://developers.theta360.com/downloads?filename=RICOH_THETA_SDK_for_iOS.0.3.0.zip"

    cd $D

    if [ -e $THETA_ZIP_FILE ]; then
        echo $THETA_FRAMEWORK" is exist."
    else
        curl -o $THETA_ZIP_FILE -LOk $THETA_CORE_URL
    fi

    unzip $THETA_ZIP_FILE

    mv $D$"/"THETA_MASTER"/lib" $D"/Classes/"
    rm -rf $D"/"$THETA_MASTER
    rm -rf $D"/"$THETA_ZIP_FILE
fi