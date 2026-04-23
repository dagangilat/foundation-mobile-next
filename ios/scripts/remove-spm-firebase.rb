#!/usr/bin/env ruby
# Undoes add-spm-firebase.rb. Removes the Firebase SPM package reference and
# product dependencies from the FoundationMobile target so the project relies
# on CocoaPods (Pods.xcworkspace) for Firebase instead.
#
# Rationale for reverting: Xcode Cloud's GitHub App install flow requires the
# app to be installed in every GitHub org that hosts a repo in the SPM graph
# (firebase, google, googleads). That's impossible for public orgs we don't
# control. CocoaPods pulls from the CocoaPods CDN over HTTPS — no per-org
# GitHub App install needed.

require 'xcodeproj'

project_path = File.expand_path('../FoundationMobile.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'FoundationMobile' }
raise 'FoundationMobile target not found' unless target

FIREBASE_REPO = 'https://github.com/firebase/firebase-ios-sdk.git'

# Strip the package reference from the root object.
removed_refs = project.root_object.package_references.select do |p|
  p.respond_to?(:repositoryURL) && p.repositoryURL == FIREBASE_REPO
end
removed_refs.each do |ref|
  project.root_object.package_references.delete(ref)
  ref.remove_from_project
end

# Strip product dependencies from the target.
doomed_products = target.package_product_dependencies.select do |dep|
  dep.respond_to?(:package) && dep.package &&
    dep.package.respond_to?(:repositoryURL) &&
    dep.package.repositoryURL == FIREBASE_REPO
end
# Same deps may have already been dissociated from their package — match by name too.
%w[FirebaseAuth FirebaseFirestore FirebaseFunctions FirebaseAppCheck FirebaseCore].each do |name|
  target.package_product_dependencies.each do |dep|
    doomed_products << dep if dep.product_name == name
  end
end
doomed_products.uniq!

# Remove the frameworks-build-phase entries that reference these deps.
frameworks_phase = target.frameworks_build_phase
frameworks_phase.files.dup.each do |bf|
  next unless bf.respond_to?(:product_ref) && bf.product_ref
  if doomed_products.include?(bf.product_ref)
    frameworks_phase.remove_build_file(bf)
  end
end

# Finally drop the product dep refs themselves.
doomed_products.each do |dep|
  target.package_product_dependencies.delete(dep)
  dep.remove_from_project
end

project.save
puts "Removed Firebase SPM: #{removed_refs.size} package refs, #{doomed_products.size} product deps."
