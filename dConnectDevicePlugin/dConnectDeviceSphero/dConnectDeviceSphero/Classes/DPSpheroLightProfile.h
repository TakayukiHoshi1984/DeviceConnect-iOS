//
//  DPSpheroLightProfile.h
//  dConnectDeviceSphero
//
//  Copyright (c) 2014 NTT DOCOMO, INC.
//  Released under the MIT license
//  http://opensource.org/licenses/mit-license.php
//
/*! @file
 @brief SpheroデバイスプラグインのLightProfile機能を提供する。
 @author NTT DOCOMO
 @date 作成日(2014.6.23)
 */
#import <DConnectSDK/DConnectLightProfile.h>
#import <Foundation/Foundation.h>
#import <RobotUIKit/RobotUIKit.h>
/*!
 @class DPSpheroLightProfile
 @brief SpheroデバイスプラグインのLightProfile機能を提供する
 */
@interface DPSpheroLightProfile : DConnectLightProfile<DConnectLightProfileDelegate>

@end
