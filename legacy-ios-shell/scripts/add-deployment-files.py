#!/usr/bin/env python3
"""
One-shot: adds DeploymentConfig.swift, DeploymentPickerView.swift,
GoogleService-Info-staging.plist to the Xcode project and bumps
CURRENT_PROJECT_VERSION to 8.

Run from the repo root:
  python3 ios/scripts/add-deployment-files.py
or from ios/:
  python3 scripts/add-deployment-files.py
"""

import os
import re
import sys

PBXPROJ = os.path.join(os.path.dirname(__file__),
                       "../FoundationMobile.xcodeproj/project.pbxproj")
PBXPROJ = os.path.normpath(PBXPROJ)

# Fixed UUIDs — chosen to not collide with anything in the project.
# Verify: grep -c DA111 FoundationMobile.xcodeproj/project.pbxproj → 0
FR_STAGING_PLIST     = "DA1110000000000000000001"  # fileRef GoogleService-Info-staging.plist
FR_DEPLOY_CONFIG     = "DA1110000000000000000002"  # fileRef DeploymentConfig.swift
FR_DEPLOY_PICKER     = "DA1110000000000000000003"  # fileRef DeploymentPickerView.swift
BF_STAGING_PLIST     = "DA1110000000000000000004"  # buildFile plist → Resources
BF_DEPLOY_CONFIG     = "DA1110000000000000000005"  # buildFile config → Sources
BF_DEPLOY_PICKER     = "DA1110000000000000000006"  # buildFile picker → Sources

NEW_BUILD_NUMBER     = 8

def bail(msg):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)

with open(PBXPROJ, encoding="utf-8") as f:
    src = f.read()

# ── Guard: skip if already applied ────────────────────────────────────────
if FR_STAGING_PLIST in src:
    print("Already applied — nothing to do.")
    sys.exit(0)

# ── 1. PBXFileReference entries ───────────────────────────────────────────
new_frefs = (
    f'\t\t{FR_STAGING_PLIST} /* GoogleService-Info-staging.plist */ = '
    f'{{isa = PBXFileReference; lastKnownFileType = text.plist.xml; '
    f'name = "GoogleService-Info-staging.plist"; '
    f'path = "FoundationMobile/GoogleService-Info-staging.plist"; sourceTree = "<group>"; }};\n'

    f'\t\t{FR_DEPLOY_CONFIG} /* DeploymentConfig.swift */ = '
    f'{{isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; '
    f'name = DeploymentConfig.swift; path = FoundationMobile/DeploymentConfig.swift; sourceTree = "<group>"; }};\n'

    f'\t\t{FR_DEPLOY_PICKER} /* DeploymentPickerView.swift */ = '
    f'{{isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = sourcecode.swift; '
    f'name = DeploymentPickerView.swift; path = FoundationMobile/DeploymentPickerView.swift; sourceTree = "<group>"; }};\n'
)

marker = "/* End PBXFileReference section */"
if marker not in src:
    bail(f"Marker not found: {marker}")
src = src.replace(marker, new_frefs + marker)

# ── 2. PBXBuildFile entries ────────────────────────────────────────────────
new_bfiles = (
    f'\t\t{BF_STAGING_PLIST} /* GoogleService-Info-staging.plist in Resources */ = '
    f'{{isa = PBXBuildFile; fileRef = {FR_STAGING_PLIST} /* GoogleService-Info-staging.plist */; }};\n'

    f'\t\t{BF_DEPLOY_CONFIG} /* DeploymentConfig.swift in Sources */ = '
    f'{{isa = PBXBuildFile; fileRef = {FR_DEPLOY_CONFIG} /* DeploymentConfig.swift */; }};\n'

    f'\t\t{BF_DEPLOY_PICKER} /* DeploymentPickerView.swift in Sources */ = '
    f'{{isa = PBXBuildFile; fileRef = {FR_DEPLOY_PICKER} /* DeploymentPickerView.swift */; }};\n'
)

marker = "/* End PBXBuildFile section */"
if marker not in src:
    bail(f"Marker not found: {marker}")
src = src.replace(marker, new_bfiles + marker)

# ── 3. PBXGroup — add to FoundationMobile group ───────────────────────────
# Anchor on the last item before the closing ); of the FoundationMobile group.
# We insert right after the Reachability.swift line (last child currently).
group_anchor = "\t\t\t\tB8C3D4E5F6789012345678AB /* Reachability.swift */,"
if group_anchor not in src:
    bail("Group anchor (Reachability.swift) not found — check pbxproj structure")

group_insert = (
    f"\t\t\t\tB8C3D4E5F6789012345678AB /* Reachability.swift */,\n"
    f"\t\t\t\t{FR_STAGING_PLIST} /* GoogleService-Info-staging.plist */,\n"
    f"\t\t\t\t{FR_DEPLOY_CONFIG} /* DeploymentConfig.swift */,\n"
    f"\t\t\t\t{FR_DEPLOY_PICKER} /* DeploymentPickerView.swift */,"
)
src = src.replace(group_anchor, group_insert)

# ── 4. PBXResourcesBuildPhase — add plist ─────────────────────────────────
resources_anchor = "\t\t\t\tCB0FADCD2F9A509100703E87 /* GoogleService-Info.plist in Resources */,"
if resources_anchor not in src:
    bail("Resources anchor (GoogleService-Info.plist) not found")

resources_insert = (
    f"\t\t\t\tCB0FADCD2F9A509100703E87 /* GoogleService-Info.plist in Resources */,\n"
    f"\t\t\t\t{BF_STAGING_PLIST} /* GoogleService-Info-staging.plist in Resources */,"
)
src = src.replace(resources_anchor, resources_insert)

# ── 5. PBXSourcesBuildPhase — add Swift files ─────────────────────────────
# Insert after AppDelegate.swift (first Sources entry — keeps logical grouping)
sources_anchor = "\t\t\t\t761780ED2CA45674006654EE /* AppDelegate.swift in Sources */,"
if sources_anchor not in src:
    bail("Sources anchor (AppDelegate.swift) not found")

sources_insert = (
    f"\t\t\t\t761780ED2CA45674006654EE /* AppDelegate.swift in Sources */,\n"
    f"\t\t\t\t{BF_DEPLOY_CONFIG} /* DeploymentConfig.swift in Sources */,\n"
    f"\t\t\t\t{BF_DEPLOY_PICKER} /* DeploymentPickerView.swift in Sources */,"
)
src = src.replace(sources_anchor, sources_insert)

# ── 6. Bump CURRENT_PROJECT_VERSION ───────────────────────────────────────
old_ver_pattern = re.compile(r'CURRENT_PROJECT_VERSION = \d+;')
matches = old_ver_pattern.findall(src)
if not matches:
    bail("CURRENT_PROJECT_VERSION not found")
src = old_ver_pattern.sub(f'CURRENT_PROJECT_VERSION = {NEW_BUILD_NUMBER};', src)
print(f"  Build number: {matches[0].split('= ')[1].rstrip(';')} → {NEW_BUILD_NUMBER} "
      f"(updated {len(matches)} occurrence{'s' if len(matches)>1 else ''})")

# ── Write ──────────────────────────────────────────────────────────────────
with open(PBXPROJ, "w", encoding="utf-8") as f:
    f.write(src)

print("Done:")
print(f"  + {FR_STAGING_PLIST[:8]}… GoogleService-Info-staging.plist (Resources)")
print(f"  + {FR_DEPLOY_CONFIG[:8]}… DeploymentConfig.swift (Sources)")
print(f"  + {FR_DEPLOY_PICKER[:8]}… DeploymentPickerView.swift (Sources)")
