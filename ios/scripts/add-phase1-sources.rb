#!/usr/bin/env ruby
# Adds AppAttestModule.swift, AppAttestModule.m, and FoundationMobile.entitlements
# to the FoundationMobile target. Idempotent — safe to re-run.

require 'xcodeproj'

project_path = File.expand_path('../FoundationMobile.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'FoundationMobile' }
raise 'FoundationMobile target not found' unless target

group = project.main_group.find_subpath('FoundationMobile', true)
group.set_source_tree('<group>')

additions = {
  'AppAttestModule.swift' => :source,
  'AppAttestModule.m' => :source,
  'FoundationMobile.entitlements' => :resource,
}

additions.each do |basename, kind|
  existing = group.files.find { |f| f.path == basename }
  ref = existing || group.new_reference(basename)

  already_built = target.source_build_phase.files_references.include?(ref) ||
    target.resources_build_phase.files_references.include?(ref)
  next if already_built

  case kind
  when :source
    target.add_file_references([ref])
  when :resource
    # Entitlements are referenced via CODE_SIGN_ENTITLEMENTS, not a build phase.
    # We still want the file reference in the group so Xcode shows it.
  end
end

project.save
puts 'Phase 1 sources registered with FoundationMobile target.'
