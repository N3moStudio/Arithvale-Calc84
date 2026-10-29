"""Package only a successful, unchanged, source-bound verification run."""
from pathlib import Path
import argparse
import hashlib
import json
import plistlib
import shutil
import struct
import zipfile
from verify_release import ROOT, source_manifest, sha

def packed_version(value):
    parts = [int(part) for part in value.split('.')]
    assert 1 <= len(parts) <= 3 and 0 < parts[0] <= 65535, 'Invalid SDK version'
    parts += [0] * (3 - len(parts))
    assert all(0 <= part <= 255 for part in parts[1:]), 'Invalid SDK version'
    return (parts[0] << 16) | (parts[1] << 8) | parts[2]

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence',type=Path,required=True)
    args=parser.parse_args()
    evidence=args.evidence.resolve()
    result=json.loads(evidence.read_text())
    assert result.get('completedAt'), 'Verification is incomplete'
    assert result['sourceFiles']==source_manifest(), 'Source differs from tested input'
    for name in ('core-tests','recovery-tests','ios-build'):
        assert result['steps'][name]['exitCode']==0, name
        assert sha(evidence.parent/(name+'.log'))==result['steps'][name]['logSHA256'], name
    brand=json.loads((ROOT/'Brand.json').read_text())
    ipa=ROOT/'xtool'/(brand['productName']+'.ipa')
    assert sha(ipa)==result['ipaSHA256'], 'IPA differs from verified build'
    with zipfile.ZipFile(ipa) as archive:
        assert archive.testzip() is None
        app='Payload/'+brand['productName']+'.app/'
        info=plistlib.loads(archive.read(app+'Info.plist'))
        for key,expected in [('CFBundleIdentifier',brand['bundleIdentifier']),('CFBundleDisplayName',brand['displayName']),
                             ('CFBundleShortVersionString',brand['version']),('CFBundleVersion',brand['build'])]:
            assert info[key]==expected,(key,info.get(key))
        assert not info.get('NSAppTransportSecurity')
        assert info['UIFileSharingEnabled'] is False and info['LSSupportsOpeningDocumentsInPlace'] is False
        assert info['UTExportedTypeDeclarations'][0]['UTTypeIdentifier']=='studio.n3mo.calc84.backup'
        assert info['CFBundleDocumentTypes'][0]['LSItemContentTypes']==['studio.n3mo.calc84.backup']
        assert any(n.endswith('PrivacyInfo.xcprivacy') for n in archive.namelist()), 'Privacy manifest absent'
        assert info['CFBundleIconFile']=='AppIcon'
        assert archive.read(app+'AppIcon.png')==(ROOT/'AppIcon.png').read_bytes(), 'Home Screen icon differs from approved export'
        identity_icons=[n for n in archive.namelist() if n.endswith('/Resources/ArithenIcon.png')]
        assert len(identity_icons)==1, 'Expected one packaged Arithen identity icon'
        assert archive.read(identity_icons[0])==(ROOT/'Sources/Calc84/Resources/ArithenIcon.png').read_bytes()
        binary=archive.read(app+info['CFBundleExecutable'])
        # Swift can encode short enum labels as instruction immediates rather
        # than contiguous strings. Layout availability/defaults have core tests;
        # inspect longer UI literals here and bind their source to the report.
        for prompt in ('Choose Backup File', 'Choose Backup Folder', 'Tap the backup filename here to select it.', 'Original capture date unavailable.', 'Receive Backup from Files', 'Use Received Backup', 'Preview Contents', 'Add from Backup', 'Save Your New Recovery Key', 'Add Backup to Setup', 'Create Library from Backups'):
            assert prompt.encode() in binary, 'Missing expected recovery/viewer UI: '+prompt
        for prompt in ('Opens file information. You can also swipe up on this handle.', 'Importing Selected Items'):
            assert prompt.encode() in binary, 'Missing expected motion/progress UI: '+prompt
        for prompt in ('Glass Tint & Video Background', 'Stops in Low Power Mode', 'Calculator Appearance', 'Choose a Library Video'):
            assert prompt.encode() in binary, 'Missing expected appearance UI: '+prompt
        for prompt in ('Your backup copies', 'Recovery not yet tested for this exact backup',
                       'Search Text in Photos', 'Index New Photos', 'Find Exact Duplicates',
                       'Tags, separated by commas', 'Edit Loop, Crop & Still Frame', 'Still frame within loop'):
            assert prompt.encode() in binary, 'Missing expected library-tools UI: '+prompt
        assert binary[:4]==bytes.fromhex('cffaedfe') and int.from_bytes(binary[4:8],'little')==0x0100000C
        commands=struct.unpack_from('<I',binary,16)[0]; position=32; min_version=None; sdk=None
        for _ in range(commands):
            command,size=struct.unpack_from('<II',binary,position); assert size>=8
            if command==0x32:
                platform,min_version,sdk=struct.unpack_from('<III',binary,position+8); assert platform==2
            position+=size
        assert min_version==(17<<16)
        sdk_version = result.get('buildEnvironment', {}).get('iosSDKVersion', '27.1')
        assert sdk == packed_version(sdk_version), 'IPA SDK differs from the SDK used for this build'
        assert not any(n.endswith('.mobileprovision') for n in archive.namelist())
    product=brand['productName']
    output=ROOT/'Releases'/(product+'-'+brand['version']+'-test-'+result['ipaSHA256'][:8])
    output.mkdir(parents=True,exist_ok=True)
    artifact=output/(product+'-'+brand['version']+'-test.ipa'); shutil.copy2(ipa,artifact)
    with zipfile.ZipFile(output/(product+'-source.zip'),'w',zipfile.ZIP_DEFLATED) as archive:
        files=set(result['sourceFiles'])
        files.update(p.relative_to(ROOT).as_posix() for p in ROOT.glob('*.md'))
        files.update(p.relative_to(ROOT).as_posix() for p in (ROOT/'Docs').rglob('*') if p.is_file())
        files.update(['LICENSE','Recover Vault.cmd','.gitignore','.gitattributes'])
        for relative in sorted(files): archive.write(ROOT/relative,Path(product)/relative)
    for name in ('core-tests','recovery-tests','ios-build'):
        shutil.copy2(evidence.parent/(name+'.log'),output/(name+'.log'))
    shutil.copy2(ROOT/'DEVICE-CHECKS.md',output/'TEST-ON-YOUR-IPHONE.md')
    result.update({'app':brand['displayName'],'version':brand['version'],'build':brand['build'],'releaseStage':'test',
                   'architecture':'arm64','minimumIOS':'17.0','sdk':sdk_version,'ipa':artifact.name})
    (output/'BUILD-RESULT.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    (output/'START-HERE.txt').write_text(
        product+' '+brand['version']+' test build\n\n'
        'Update using the same signing identity and data container. Do not uninstall your current library.\n'
        'Enter your existing code and HOLD =. On an empty installation use 160160 and hold =.\n'
        'The display name changed; bundle identity and backup formats did not.\n'
        'This IPA is unsigned. Use your existing SideStore or other signing setup.\n'
        f"Fresh checks: {result['coreTests']['passed']} Swift tests; {result['independentRecoveryTests']['passed']} independent Python recovery tests; iOS arm64 build.\n"
        'Phone installation/UI and real MEGA/Blomp account transfers are NOT verified here.\n'
        'Follow TEST-ON-YOUR-IPHONE.md with disposable media before relying on this build.\n',encoding='utf-8')
    print('Test kit: '+str(output))

if __name__=='__main__': main()
