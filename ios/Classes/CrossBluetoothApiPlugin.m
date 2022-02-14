#import "CrossBluetoothApiPlugin.h"
#if __has_include(<cross_bluetooth_api/cross_bluetooth_api-Swift.h>)
#import <cross_bluetooth_api/cross_bluetooth_api-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "cross_bluetooth_api-Swift.h"
#endif

@implementation CrossBluetoothApiPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftCrossBluetoothApiPlugin registerWithRegistrar:registrar];
}
@end
