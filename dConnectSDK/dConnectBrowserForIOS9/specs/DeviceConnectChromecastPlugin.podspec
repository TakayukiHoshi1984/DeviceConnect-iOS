# TODO: ApplicationIDの追加
Pod::Spec.new do |s|
    
    s.name         = "DeviceConnectChromecastPlugin"
    s.version      = "2.0.0"
    s.summary      = "Device Connect Plugin for Chromecast"
    
    s.description  = <<-DESC
    A Device Connect plugin for Chromecast.
    
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
        :git => $targetSource, :branch => 'modify_project'
    }
    
    # エンドターゲット（アプリとか）のDebugビルドの際、対応するアーキテクチャが含まれていない
    # という旨で提供するライブラリがビルドされない問題への対処。
    s.pod_target_xcconfig = { 'ONLY_ACTIVE_ARCH' => 'NO' }
    
    common_resource_exts = "plist,lproj,storyboard,strings,xcdatamodeld,png,xcassets"
    base_path = "dConnectDevicePlugin/dConnectDeviceChromeCast"
    application_id = $chromeCastApplicationId
    s.prepare_command = <<-CMD
    	cd dConnectDevicePlugin/dConnectDeviceChromeCast/dConnectDeviceChromecast/Classes
		sed -i -e "s/Your Application Id/#{application_id}/g" DPChromecastManager.m
		rm DPChromecastManager.m-e
    CMD
    s.prefix_header_file = base_path + "/dConnectDeviceChromecast/dConnectDeviceChromecast-Prefix.pch"
    s.private_header_files = base_path + "/dConnectDeviceChromecast/Classes/**/*.h"
    s.source_files = base_path + "/dConnectDeviceChromecast/Classes/**/*.{h,m}"
    s.resource_bundles = {
    		"dConnectDeviceChromecast_resources" => [
    			base_path + "/dConnectDeviceChromecast/**/**/*.{#{common_resource_exts}}",
    			base_path + "/dConnectDeviceChromeCast_resources/*.{#{common_resource_exts}}"
    		]
    }
    s.dependency "google-cast-sdk"
    s.dependency "DeviceConnectSDK"
    
end
