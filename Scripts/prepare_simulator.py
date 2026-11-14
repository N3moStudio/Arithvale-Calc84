"""Generate a simulator-only Xcode host from the production sources, without test bypasses.

The normal IPA remains built by xtool. This host uses the real MEGA simulator
slice, real encryption and normal setup UI; no mock provider or unlock hook.
"""
from pathlib import Path
import json
import os
import plistlib
import subprocess

root = Path(__file__).resolve().parents[1]
output = root / '.build/simulator'
engine = output / 'Engine'
engine.mkdir(parents=True, exist_ok=True)
for directory in ('Sources', 'Vendor', 'Tests'):
    (engine / directory).symlink_to(root / directory, target_is_directory=True)

# Reuse the production core/native dependency targets. Calc84 is compiled by the
# Xcode app target so XCTest can launch it as a real application, not a library.
manifest = (root / 'Package.swift').read_text()
start = manifest.index('    products: [')
end = manifest.index('    dependencies: cryptoPackages,', start)
manifest = manifest[:start] + '    products: [.library(name: "Engine", targets: ["CalcCore", "CalcMega"])],\n' + manifest[end:]
start = manifest.index('        .target(\n            name: "Calc84"')
end = manifest.index('        .target(name: "MEGACore"', start)
manifest = manifest[:start] + manifest[end:]
(engine / 'Package.swift').write_text(manifest)

# SwiftPM synthesizes Bundle.module for production. The Xcode host copies the
# same Resources folder into its main bundle; this shim is never in the IPA.
(output / 'SimulatorResources.swift').write_text('import Foundation\nextension Bundle { static var module: Bundle { .main } }\n')
info = plistlib.loads((root / 'Sources/Calc84/Info.plist').read_bytes())
info.update(CFBundleIdentifier='$(PRODUCT_BUNDLE_IDENTIFIER)', CFBundleExecutable='$(EXECUTABLE_NAME)',
            CFBundleName='Arithen', CFBundlePackageType='APPL', CFBundleInfoDictionaryVersion='6.0')
with (output / 'Info.plist').open('wb') as stream:
    plistlib.dump(info, stream)

settings = {'SWIFT_VERSION': '5.0', 'IPHONEOS_DEPLOYMENT_TARGET': '17.0',
            'CODE_SIGN_IDENTITY': '-', 'CODE_SIGNING_ALLOWED': 'YES', 'TARGETED_DEVICE_FAMILY': '1,2'}
spec = {'name': 'ArithenSimulator', 'options': {'deploymentTarget': {'iOS': '17.0'}},
        'settings': {'base': settings}, 'packages': {'Engine': {'path': str(engine)}},
        'targets': {
            'Arithen': {'type': 'application', 'platform': 'iOS',
                'sources': [{'path': str(root / 'Sources/Calc84'), 'excludes': ['Info.plist', 'Resources', 'PrivacyInfo.xcprivacy']},
                            {'path': str(output / 'SimulatorResources.swift')},
                            {'path': str(root / 'Sources/Calc84/Resources'), 'type': 'folder', 'buildPhase': 'resources'},
                            {'path': str(root / 'Sources/Calc84/PrivacyInfo.xcprivacy'), 'buildPhase': 'resources'}],
                'dependencies': [{'package': 'Engine', 'product': 'Engine'}],
                'settings': {'base': {'PRODUCT_BUNDLE_IDENTIFIER': 'studio.n3mo.calc84',
                                     'INFOPLIST_FILE': str(output / 'Info.plist')}}},
            'ArithenUITests': {'type': 'bundle.ui-testing', 'platform': 'iOS',
                'sources': [str(root / 'Tests/ArithenUITests')],
                'dependencies': [{'target': 'Arithen'}],
                'settings': {'base': {'PRODUCT_BUNDLE_IDENTIFIER': 'studio.n3mo.calc84.uitests',
                                     'GENERATE_INFOPLIST_FILE': 'YES', 'TEST_TARGET_NAME': 'Arithen'}}}},
        'schemes': {'Arithen': {'build': {'targets': {'Arithen': 'all', 'ArithenUITests': ['test']}},
                    'test': {'targets': ['ArithenUITests'], 'gatherCoverageData': False}}}}
(output / 'project.json').write_text(json.dumps(spec, indent=2))
subprocess.run(['xcodegen', 'generate', '--spec', str(output / 'project.json'), '--project', str(output)], check=True)
inventory = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', '--json']))
runtime = os.environ['ARITHEN_SIMULATOR_RUNTIME']
assert any(r['identifier'] == runtime and r.get('isAvailable') for r in inventory['runtimes']), 'Required iOS simulator runtime unavailable'
# Use a disposable device, not a runner-image device with stale migration state.
device_type = next(d for d in inventory['devicetypes'] if d['name'] == 'iPhone 17 Pro')
udid = subprocess.check_output(['xcrun', 'simctl', 'create', 'Arithen CI', device_type['identifier'], runtime], text=True).strip()
device = {'name': 'Arithen CI (iPhone 17 Pro)', 'udid': udid, 'deviceTypeIdentifier': device_type['identifier']}
(output / 'device.json').write_text(json.dumps({'runtime': runtime, **device}, indent=2))
(output / 'device-id.txt').write_text(device['udid'])
print('Simulator:', device['name'], runtime)
