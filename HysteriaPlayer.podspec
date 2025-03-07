Pod::Spec.new do |s|
  s.name         = "HysteriaPlayer"
  s.version      = "2.3.0"
  s.summary      = "Objective-C remote audio player (AVPlayer extends), iOS, OS X compatible"
  s.homepage     = "https://github.com/StreetVoice/HysteriaPlayer"
  s.license      = 'MIT'
  s.author       = { "Stan Tsai" => "feocms@gmail.com" }
  s.source       = { :git => "https://github.com/StreetVoice/HysteriaPlayer.git", :tag => "2.3.0" }
  s.ios.deployment_target = '12.0'
  s.osx.deployment_target = '10.13'
  s.source_files = 'HysteriaPlayer/**/*.{h,m}'
  s.resources    = 'HysteriaPlayer/point1sec.{mp3}'
  s.frameworks   = 'CoreMedia', 'AudioToolbox', 'AVFoundation'
  s.requires_arc = true
end
