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
  AntiSpoofProducer.swift
  CoreMLFaceEmbedder.swift
  AppConfig.swift
  QRScannerView.swift
  PairingCoordinator.swift
  DocumentPhotoView.swift
  SupportSheet.swift
  WebHomeView.swift
  SupportSessionTracker.swift
]

# Profile JSONs are sources for the select-profile.sh build phase; the script
# copies the active one into the bundle as foundationmobile.json. They are
# NOT added to Copy Bundle Resources (the script writes the output directly).
# Listed here so Xcode shows them in the navigator.
profile_files = %w[
  Resources/profiles/hisec-global.json
  Resources/profiles/standardsec.json
  Resources/profiles/lowsec-attest.json
]

resources = %w[
  GoogleService-Info.plist
]

# Core ML model packages: .mlpackage is a directory bundle; xcodeproj treats
# it as a single file ref with last_known_file_type "wrapper" (Xcode then
# compiles to .mlmodelc at build time and bundles the compiled form).
ml_packages = %w[
  Resources/SilentFaceMiniFASNetV2.mlpackage
  Resources/SilentFaceMiniFASNetV1SE.mlpackage
  Resources/MobileFaceNet.mlpackage
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

# .mlpackage handling — find or create with the wrapper file type Xcode
# uses for Core ML packages.
ml_packages.each do |relative|
  basename = File.basename(relative)
  full_relative = "FoundationMobile/#{relative}"
  existing = group.recursive_children.find do |f|
    f.respond_to?(:path) && (f.path == full_relative || f.path == relative || f.name == basename)
  end
  ref = existing || group.new_reference(full_relative)
  ref.path = full_relative
  ref.name = basename
  ref.last_known_file_type = 'wrapper'
  target.resources_build_phase.add_file_reference(ref) unless target.resources_build_phase.files_references.include?(ref)
end

# Profile JSONs — show in navigator only; not bundled directly.
profile_files.each do |relative|
  basename = File.basename(relative)
  full_relative = "FoundationMobile/#{relative}"
  existing = group.recursive_children.find do |f|
    f.respond_to?(:path) && (f.path == full_relative || f.path == relative || f.name == basename)
  end
  ref = existing || group.new_reference(full_relative)
  ref.path = full_relative
  ref.name = basename
  ref.last_known_file_type = 'text.json'
end

# Run Script Build Phase — bakes the active profile JSON into the bundle as
# foundationmobile.json. Inserted once; idempotent on re-runs.
phase_name = 'Select Foundation profile JSON'
existing_phase = target.shell_script_build_phases.find { |p| p.name == phase_name }
unless existing_phase
  phase = target.new_shell_script_build_phase(phase_name)
  phase.shell_path = '/bin/sh'
  phase.shell_script = '"${SRCROOT}/scripts/select-profile.sh"'
  phase.input_paths = [
    '$(SRCROOT)/FoundationMobile/Resources/profiles/$(FOUNDATION_PROFILE).json',
    '$(SRCROOT)/scripts/select-profile.sh',
  ]
  phase.output_paths = [
    '$(BUILT_PRODUCTS_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/foundationmobile.json',
  ]
  phase.always_out_of_date = '1'  # FOUNDATION_PROFILE may flip between builds
end

project.save
puts 'Swift sources + resources + ML packages + profile JSONs + Run Script registered.'
