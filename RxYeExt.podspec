Pod::Spec.new do |s|
  s.name             = 'RxYeExt'
  s.version          = '0.0.1'
  s.summary          = 'Rxswift ext'
  s.description      = <<-DESC
                        Rxswift ext
                      DESC
  s.homepage         = 'https://github.com/Yewenyu/RxYeExt'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'ye' => '****' }
  s.source           = { :git => 'https://github.com/Yewenyu/RxYeExt.git', :tag => "#{s.version}" }
  s.ios.deployment_target = '11.0'
  s.source_files     = 'RxYeExt/**/*.{swift,h}'
  s.swift_version    = '5.0'
  
  # 如果你的框架依赖于其他第三方库，可以在这里添加依赖
  # s.dependency 'AnotherPod', '~> 1.0'
  s.dependency pod 'RxSwift'
  s.dependency pod 'RxCocoa'
  s.dependency pod 'RxRelay'
  s.dependency pod 'RxDataSources'
end

# pod trunk register your_email@example.com 'Your Name'
# pod trunk push QuickStoreKit.podspec
