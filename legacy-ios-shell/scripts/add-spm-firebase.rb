#!/usr/bin/env ruby
# Adds the Firebase iOS SDK as an SPM package dependency on the FoundationMobile
# target. Idempotent — safe to re-run.

require 'xcodeproj'

project_path = File.expand_path('../FoundationMobile.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'FoundationMobile' }
raise 'FoundationMobile target not found' unless target

FIREBASE_REPO = 'https://github.com/firebase/firebase-ios-sdk.git'
MIN_VERSION = '12.0.0'

# Ensure the package reference exists.
existing_ref = project.root_object.package_references.find do |p|
  p.respond_to?(:repositoryURL) && p.repositoryURL == FIREBASE_REPO
end
package_ref = existing_ref || begin
  ref = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
  ref.repositoryURL = FIREBASE_REPO
  ref.requirement = { 'kind' => 'upToNextMajorVersion', 'minimumVersion' => MIN_VERSION }
  project.root_object.package_references << ref
  ref
end

# Attach the specific products we consume.
products = %w[
  FirebaseAuth
  FirebaseFirestore
  FirebaseFunctions
  FirebaseAppCheck
  FirebaseCore
]

products.each do |name|
  existing = target.package_product_dependencies.find { |d| d.product_name == name }
  next if existing
  dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dep.package = package_ref
  dep.product_name = name
  target.package_product_dependencies << dep
end

# Also wire each product into the target's frameworks build phase so the
# linker actually pulls them in.
frameworks_phase = target.frameworks_build_phase
target.package_product_dependencies.each do |dep|
  next if frameworks_phase.files.any? do |f|
    f.respond_to?(:product_ref) && f.product_ref == dep
  end
  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = dep
  frameworks_phase.files << build_file
end

project.save
puts "Firebase SPM package wired (#{FIREBASE_REPO}, >= #{MIN_VERSION})."
puts "Products: #{products.join(', ')}"
