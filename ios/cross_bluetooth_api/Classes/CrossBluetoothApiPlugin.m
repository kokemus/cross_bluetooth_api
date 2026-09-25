#import "CrossBluetoothApiPlugin.h"
#if __has_include(<cross_bluetooth_api/cross_bluetooth_api-Swift.h>)
#import <cross_bluetooth_api/cross_bluetooth_api-Swift.h>
#else
#import "cross_bluetooth_api-Swift.h"
#endif

@implementation CrossBluetoothApiPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftCrossBluetoothApiPlugin registerWithRegistrar:registrar];
}
@end
