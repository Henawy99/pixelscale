Pod::Spec.new do |s|
  s.name           = 'ShareSheet'
  s.version        = '1.0.0'
  s.summary        = 'Shares several files and a message through one iOS share sheet'
  s.description    = 'Shares several files and a message through one iOS share sheet, e.g. tour photos to WhatsApp.'
  s.license        = 'MIT'
  s.author         = 'PixelScale'
  s.homepage       = 'https://docs.expo.dev/modules/'
  s.platforms      = { :ios => '16.4' }
  s.swift_version  = '5.9'
  s.source         = { git: '' }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'

  s.source_files = '**/*.swift'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_COMPILATION_MODE' => 'wholemodule'
  }
end
