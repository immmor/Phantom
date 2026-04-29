Pod::Spec.new do |s|
  s.name         = 'ClashCore'
  s.version      = '1.0.0'
  s.summary      = 'Go Clash Core Framework for iOS'
  s.description  = 'A Go framework binding for Clash core to be used in iOS NetworkExtension'
  s.homepage     = 'https://github.com/chen08209/FlClash'
  s.license      = { :type => 'GPL-3.0', :file => 'LICENSE' }
  s.author       = { 'chen08209' => 'chen08209@gmail.com' }
  s.platform     = :ios, '13.0'
  s.source       = { :path => '.' }
  s.source_files = '*.swift', '*.h'
  s.public_header_files = '*.h'
  s.frameworks   = 'Foundation', 'NetworkExtension'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SKIP_INSTALL' => 'YES'
  }
end