# add-test-target.rb — idempotent: adds a unit-test target + shared scheme test
# action to FoundationMobile.xcodeproj. Run once (re-run to register new test
# files). Requires: gem install xcodeproj.
require 'xcodeproj'

proj_path = File.expand_path('../FoundationMobile.xcodeproj', __dir__)
project   = Xcodeproj::Project.open(proj_path)
app       = project.targets.find { |t| t.name == 'FoundationMobile' }
raise 'app target missing' unless app

test = project.targets.find { |t| t.name == 'FoundationMobileTests' }
unless test
  test = project.new_target(:unit_test_bundle, 'FoundationMobileTests', :ios, '16.0')
  test.add_dependency(app)
end
# Apply settings unconditionally so re-runs repair an existing target. Notably
# PRODUCT_NAME must be set — without it the bundle links to PlugIns/.xctest
# (empty name) and the dir-create + link commands collide ("Multiple commands
# produce").
test.build_configurations.each do |c|
  c.build_settings['PRODUCT_NAME']              = '$(TARGET_NAME)'
  c.build_settings['TEST_HOST']                 = '$(BUILT_PRODUCTS_DIR)/FoundationMobile.app/FoundationMobile'
  c.build_settings['BUNDLE_LOADER']             = '$(TEST_HOST)'
  c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.foundationglobal.mobile.tests'
  c.build_settings['GENERATE_INFOPLIST_FILE']   = 'YES'
  c.build_settings['SWIFT_VERSION']             = '5.0'
  c.build_settings['IPHONEOS_DEPLOYMENT_TARGET']= '16.0'
  c.build_settings['CODE_SIGNING_ALLOWED']      = 'NO'
end

# Register every *.swift under FoundationMobileTests/ that isn't already in the
# target's compile sources.
group = project.main_group.find_subpath('FoundationMobileTests', true)
group.set_source_tree('<group>')
existing = test.source_build_phase.files_references.map { |r| r.path }
Dir[File.join(__dir__, '..', 'FoundationMobileTests', '*.swift')].sort.each do |f|
  rel = "FoundationMobileTests/#{File.basename(f)}"
  next if existing.include?(rel)
  ref = group.files.find { |r| r.path == rel } || group.new_reference(rel)
  test.add_file_references([ref])
end
project.save

# Shared scheme so `xcodebuild test -scheme FoundationMobile` runs the bundle.
shared_dir  = Xcodeproj::XCScheme.shared_data_dir(proj_path)
scheme_file = File.join(shared_dir, 'FoundationMobile.xcscheme')
scheme = File.exist?(scheme_file) ? Xcodeproj::XCScheme.new(scheme_file) : Xcodeproj::XCScheme.new
scheme.add_build_target(app) if scheme.build_action.entries.empty?
already = scheme.test_action.testables.any? do |t|
  t.buildable_references.first&.target_name == 'FoundationMobileTests'
end
unless already
  scheme.test_action.add_testable(Xcodeproj::XCScheme::TestAction::TestableReference.new(test))
end
scheme.save_as(proj_path, 'FoundationMobile', true)
puts 'FoundationMobileTests target + scheme test action ready.'
