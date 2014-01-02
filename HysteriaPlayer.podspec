Pod::Spec.new do |s|
  s.name                 = "HysteriaPlayer"
  s.version              = "1.5.1"
  s.summary              = "Objective-C remote audio player (AVPlayer extends)"
  s.homepage             = "https://github.com/StreetVoice/HysteriaPlayer"
  # s.screenshots        = "www.example.com/screenshots_1", "www.example.com/screenshots_2"
  s.license              = { :type => 'MIT', :file => 'LICENSE' }
  s.author               = { "Stan Tsai" => "feocms@gmail.com" }
  s.social_media_url     = "http://twitter.com/saiday"
  s.platform             = :ios, '6.0'
  s.source               = { :git => "https://github.com/StreetVoice/HysteriaPlayer.git", :tag => "1.5.1"}
  s.source_files         = 'HysteriaPlayer/**/*.{h,m}'
  s.public_header_files  = 'HysteriaPlayer/**/*.h'
  s.resources            = "HysteriaPlayer/point1sec.mp3"

  s.frameworks           = "CoreMedia", "AudioToolbox", "AVFoundation"
  s.requires_arc         = true
end
