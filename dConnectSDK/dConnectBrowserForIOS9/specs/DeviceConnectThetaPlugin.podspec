
Pod::Spec.new do |s|
    
    s.name         = "DeviceConnectThetaPlugin"
    s.version      = "2.0.0"
    s.summary      = "Device Connect Plugin for Ricoh THETA"
    
    s.description  = <<-DESC
    A Device Connect plugin for Ricoh THETA device family.
    
    You need to sign up and download RICOH THETA SDK at the developer center: https://developers.theta360.com/en/docs/sdk/download.html .
    Also, path to the SDK zip file must be set to environment variable DC_THETA_SDK_ZIP_PATH when installing or updating this Pod.
    
    Device Connect is an IoT solution for interconnecting various modern devices.
    Also available in Android: https://github.com/DeviceConnect/DeviceConnect-Android .
    DESC
    
    s.homepage     = "https://github.com/DeviceConnect/DeviceConnect-iOS"
    # s.screenshots  = "www.example.com/screenshots_1.gif", "www.example.com/screenshots_2.gif"
    
    s.license      = {:type => "MIT", :file => "LICENSE.TXT"}
    
    s.author       = "NTT DOCOMO, INC."
    # s.authors            = { "NTT DOCOMO, INC." => "*****@*****" }
    # s.social_media_url   = "https://www.facebook.com/docomo.official"
    
    # プロパティのweak属性と、automatic property synthesisをサポートするために6.0以降が必要。
    s.platform     = :ios, "9.0"
    
    s.source       = {
        :git => $targetSource, :branch => "modify_project" # TODO:masterにマージするときに戻す
    }
    

    # エンドターゲット（アプリとか）のDebugビルドの際、対応するアーキテクチャが含まれていない
    # という旨で提供するライブラリがビルドされない問題sへの対処。
    s.pod_target_xcconfig = { 'ONLY_ACTIVE_ARCH' => 'NO' }
    
    common_resource_exts = "plist,lproj,storyboard,strings,xcdatamodeld,png"
    base_path = "dConnectDevicePlugin/dConnectDeviceTheta"
    s.prepare_command = <<-CMD
		cd dConnectDevicePlugin/dConnectDeviceTheta/
		sh ./download-lib.sh
    CMD

    s.libraries   = 'iconv'
    s.public_header_files = base_path + "/dConnectDeviceTheta/Headers/*.h"
    s.source_files = base_path + "/dConnectDeviceTheta/Headers/*.h",
    				 base_path + "/dConnectDeviceTheta/Classes/**/*.{h,m}",
    				 base_path + "/dConnectDeviceTheta/Classes/lib/**/*.{h,mm,m}",
    				 base_path + "/dConnectDeviceTheta/Classes/lib/**/**/*.{h,mm,cpp}"


    s.resource_bundles = {"dConnectDeviceTheta_resources" => [base_path + "/dConnectDeviceTheta/Resources/**/*.{#{common_resource_exts}}"]}
    
    s.dependency "DeviceConnectSDK"

end
