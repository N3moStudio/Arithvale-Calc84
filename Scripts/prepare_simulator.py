"""Generate a simulator-only Xcode host from the production sources, without test bypasses.

The normal IPA remains built by xtool. This host uses the real MEGA simulator
slice, real encryption and normal setup UI; no mock provider or unlock hook.
"""
from pathlib import Path
import json
import os
import plistlib
import shutil
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

# A root Resources directory makes Apple's bundle classifier treat the app as
# a different bundle layout. Keep the exact resource-relative paths one level
# below SimulatorAssets. This adapter is only in the generated simulator host.
assets = output / 'SimulatorAssets'
shutil.copytree(root / 'Sources/Calc84/Resources', assets / 'Resources')
(output / 'SimulatorResources.swift').write_text('''import Foundation
struct SimulatorResources {
    var resourceURL: URL? { Bundle.main.resourceURL?.appendingPathComponent("SimulatorAssets") }
    func url(forResource name: String, withExtension ext: String, subdirectory: String) -> URL? {
        resourceURL?.appendingPathComponent(subdirectory).appendingPathComponent(name).appendingPathExtension(ext)
    }
}
extension Bundle { static let module = SimulatorResources() }
''')
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
                            {'path': str(assets), 'type': 'folder', 'buildPhase': 'resources'},
                            {'path': str(root / 'Sources/Calc84/PrivacyInfo.xcprivacy'), 'buildPhase': 'resources'}],
                'dependencies': [{'package': 'Engine', 'product': 'Engine'}],
                'settings': {'base': {'PRODUCT_BUNDLE_IDENTIFIER': 'studio.n3mo.calc84',
                                     'INFOPLIST_FILE': str(output / 'Info.plist')}}},
            'ArithenAppTests': {'type': 'bundle.unit-test', 'platform': 'iOS',
                'sources': [str(root / 'Tests/ArithenAppTests')],
                'dependencies': [{'target': 'Arithen'}, {'package': 'Engine', 'product': 'Engine'}],
                'settings': {'base': {'PRODUCT_BUNDLE_IDENTIFIER': 'studio.n3mo.calc84.apptests',
                                     'GENERATE_INFOPLIST_FILE': 'YES', 'TEST_HOST': '$(BUILT_PRODUCTS_DIR)/Arithen.app/Arithen',
                                     'BUNDLE_LOADER': '$(TEST_HOST)'}}},
            'ArithenUITests': {'type': 'bundle.ui-testing', 'platform': 'iOS',
                'sources': [str(root / 'Tests/ArithenUITests')],
                'dependencies': [{'target': 'Arithen'}],
                'settings': {'base': {'PRODUCT_BUNDLE_IDENTIFIER': 'studio.n3mo.calc84.uitests',
                                     'GENERATE_INFOPLIST_FILE': 'YES', 'TEST_TARGET_NAME': 'Arithen'}}}},
        'schemes': {'Arithen': {'build': {'targets': {'Arithen': 'all', 'ArithenUITests': ['test'], 'ArithenAppTests': ['test']}},
                    'test': {'targets': ['ArithenAppTests', 'ArithenUITests'], 'gatherCoverageData': False}}}}
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
