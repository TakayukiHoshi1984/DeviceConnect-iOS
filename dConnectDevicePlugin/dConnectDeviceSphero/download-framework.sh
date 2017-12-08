#!/bin/sh


D=$(cd $(dirname $0);pwd)

# SpheroのSDKへのパス
SPHERO_ROBOTKIT_FRAMEWORK="/RobotKit.framework"
SPHERO_ROBOTUIKIT_FRAMEWORK="/RobotUIKit.framework"
SPHERO_ROBOTUIKIT_BUNDLE="/RobotUIKit.bundle"
SPHERO_SDK=$D"/"$SPHERO_ROBOTKIT_FRAMEWORK

# GitHubからのダウンロード設定
SPHERO_CORE_URL="https://github.com/orbotix/Sphero-iOS-SDK/archive/master.zip"
SPHERO_MASTER="Sphero-iOS-SDK-master"
SPHERO_ZIP_FILE=$SPHERO_MASTER".zip"

# Spheroのダウンロード確認
if [ -d $SPHERO_SDK ]; then
    echo "Sphero sdk is exist."
else
    # Sphero sdkが存在しない場合には終了
    echo "Sphero sdk is not exist."
    echo ""
    echo "SpheroSDKダウンロードページより、ダウンロード。"
    echo "https://github.com/orbotix/Sphero-iOS-SDK"

    cd $D

    if [ -e $SPHERO_ZIP_FILE ]; then
        echo $SPHERO_FRAMEWORK" is exist."
    else
        curl -o $SPHERO_ZIP_FILE -LOk $SPHERO_CORE_URL
    fi

    unzip $SPHERO_ZIP_FILE
    mv $D"/"$SPHERO_MASTER"/frameworks/"$SPHERO_ROBOTKIT_FRAMEWORK"/Frameworks/RobotCommandKit.framework" $D
    mv $D"/"$SPHERO_MASTER"/frameworks/"$SPHERO_ROBOTKIT_FRAMEWORK"/Frameworks/RobotKitClassic.framework" $D
    mv $D"/"$SPHERO_MASTER"/frameworks/"$SPHERO_ROBOTKIT_FRAMEWORK"/Frameworks/RobotKitLE.framework" $D
    mv $D"/"$SPHERO_MASTER"/frameworks/"$SPHERO_ROBOTKIT_FRAMEWORK"/Frameworks/RobotLanguageKit.framework" $D
    mv $D"/"$SPHERO_MASTER"/frameworks/"$SPHERO_ROBOTKIT_FRAMEWORK $D
    mv $D"/"$SPHERO_MASTER"/frameworks/"$SPHERO_ROBOTUIKIT_FRAMEWORK $D
    mv $D"/"$SPHERO_MASTER"/frameworks/"$SPHERO_ROBOTUIKIT_BUNDLE $D
    rm -rf $D"/"$SPHERO_MASTER
    rm -rf $D"/"$SPHERO_ZIP_FILE
fi