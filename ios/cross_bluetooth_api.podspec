#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint cross_bluetooth_api.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'cross_bluetooth_api'
  s.version          = '0.0.1'
  s.summary          = 'Cross-platform Web Bluetooth style API for Flutter.'
  s.description      = <<-DESC
The Cross Bluetooth API provides the ability to connect and interact with Bluetooth Low Energy peripherals.
                       DESC
  s.homepage         = 'https://github.com/kokemus/cross_bluetooth_api'
  s.license          = { :type => 'UNKNOWN', :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :git => 'https://github.com/kokemus/cross_bluetooth_api.git', :tag => s.version.to_s }
  s.source_files     = 'cross_bluetooth_api/Sources/cross_bluetooth_api/**/*.swift', 'cross_bluetooth_api/Classes/**/*.{h,m}'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
