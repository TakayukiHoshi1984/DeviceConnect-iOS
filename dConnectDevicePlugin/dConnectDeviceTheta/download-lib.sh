#!/bin/bash


D=$(cd $(dirname $0);pwd)

# THETAのSDKへのパス
THETA_R_EXIF="lib-r-exif"
THETA_RICOH_THETA="lib-ricoh-theta"
THETA_RICOH_THETA_SERIALIZER="lib-ricoh-theta_serializer"
THETA_SDK=$D"/dConnectDeviceTheta/Classes/lib"

THETA_CORE_URL="https://developers.theta360.com/ja/docs/sdk/download.html"
THETA_MASTER="RICOH_THETA_SDK_for_iOS.0.3.0"
THETA_ZIP_FILE=$THETA_MASTER".zip"
# THETAのダウンロード確認
if [ -d $THETA_SDK ]; then
    echo "THETA sdk is exist."
else
    # THETA sdkが存在しない場合にはダウンロードページから手動でダウンロードしてもらう
    echo "THETA sdk is not exist."
    echo ""
    echo "Please download SDK from THETA Developer page."
    echo "https://developers.theta360.com/ja/docs/sdk/download.html"

    cd $D

    if [ -e $THETA_ZIP_FILE ]; then
        echo $THETA_FRAMEWORK" is exist."
    else
    	# Safariで開く
		open -a safari $THETA_CORE_URL
    fi

	read -p "Did you download Theta SDK? : ok?(Please press any key) :" yn
	case "$yn" in
	 *)
		mv "$HOME/Downloads/"$THETA_MASTER"/lib" $THETA_SDK
		rm -rf "$HOME/Downloads/"$THETA_MASTER
	  ;;
	esac
fi