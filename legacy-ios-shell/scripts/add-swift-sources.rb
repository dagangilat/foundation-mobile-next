#!/usr/bin/env ruby
# Idempotent Xcode-project source registration for the native Swift pivot
# (2026-04-23). Adds Swift sources + GoogleService-Info.plist to the
# FoundationMobile target, and removes stale RN-bridge files.

require 'xcodeproj'

project_path = File.expand_path('../FoundationMobile.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'FoundationMobile' }
raise 'FoundationMobile target not found' unless target

group = project.main_group.find_subpath('FoundationMobile', true)
group.set_source_tree('<group>')

sources = %w[
  FoundationMobileApp.swift
  AppDelegate.swift
  Theme.swift
  Keychain.swift
  AuthService.swift
  FirestoreService.swift
  FunctionsService.swift
  AttestationService.swift
  AppCheckFactory.swift
  SolanaRPC.swift
  RootView.swift
  LoadingView.swift
  SignInView.swift
  HomeView.swift
  WalletDocumentReader.swift
]

resources = %w[
  GoogleService-Info.plist
]

# Files previously registered for the RN bridge; remove from all build phases
# and the project (the on-disk files are already gone).
stale = %w[AppAttestModule.swift AppAttestModule.m]

stale.each do |name|
  refs = project.files.select do |f|
    File.basename(f.path.to_s) == name || f.name == name
  end
  refs.each do |ref|
    target.source_build_phase.remove_file_reference(ref)
    target.resources_build_phase.remove_file_reference(ref)
    ref.remove_from_project
  end
end

# Stale RN run-script build phases (from the react-native init template).
stale_script_phases = [
  'Bundle React Native code and images',
  'Start Packager',
  '[CP-User] [RNFB] Core Configuration',
]
doomed = target.build_phases.select do |phase|
  phase.is_a?(Xcodeproj::Project::Object::PBXShellScriptBuildPhase) &&
    phase.respond_to?(:name) &&
    stale_script_phases.include?(phase.name)
end
doomed.each do |phase|
  target.build_phases.delete(phase)
  phase.remove_from_project
end

def upsert(group, basename)
  relative_path = "FoundationMobile/#{basename}"
  existing = group.files.find do |f|
    f.path == relative_path || f.path == basename || f.name == basename
  end
  ref = existing || group.new_reference(relative_path)
  ref.path = relative_path
  ref.name = basename
  ref
end

sources.each do |name|
  ref = upsert(group, name)
  target.add_file_references([ref]) unless target.source_build_phase.files_references.include?(ref)
end

resources.each do |name|
  ref = upsert(group, name)
  target.resources_build_phase.add_file_reference(ref) unless target.resources_build_phase.files_references.include?(ref)
end

project.save
puts 'Swift sources + resources registered with FoundationMobile target.'
