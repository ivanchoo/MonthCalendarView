Pod::Spec.new do |s|
  s.name = 'MonthCalendarView'
  s.version = '1.0.0'
  s.license = 'MIT'
  s.summary = 'Calendar View for iOS'
  s.homepage = 'https://github.com/ivanchoo/MonthCalendarView'
  s.social_media_url = 'http://twitter.com/ivanchoo'
  s.authors = { 'Ivan Choo' => 'hello@ivanchoo.com' }
  s.source = { :git => 'https://github.com/ivanchoo/MonthCalendarView.git', :tag => s.version }

  s.ios.deployment_target = '8.0'

  s.source_files = 'MonthCalendarView/*.swift'

  s.requires_arc = true
end
