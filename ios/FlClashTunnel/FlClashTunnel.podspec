Pod::Spec.new do |s|
  s.name         = 'FlClashTunnel'
  s.version      = '1.0.0'
  s.summary      = 'NetworkExtension Packet Tunnel Provider for FlClash'
  s.description  = 'A packet tunnel provider that enables VPN functionality for FlClash on iOS'
  s.homepage     = 'https://github.com/chen08209/FlClash'
  s.license      = { :type => 'GPL-3.0', :file => 'LICENSE' }
  s.author       = { 'chen08209' => 'chen08209@gmail.com' }
  s.platform     = :ios, '13.0'
  s.source       = { :path => '.' }
  s.source_files = '*.swift'
  s.resources    = 'Info.plist'
  s.frameworks   = 'NetworkExtension', 'Foundation'
  s.swift_version = '5.0'

  s.dependency 'ClashCore'
  s.dependency 'Flutter'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SKIP_INSTALL' => 'YES'
  }
end