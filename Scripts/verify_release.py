"""Run fresh checks sequentially, bind evidence to source hashes, then package.

macOS with Xcode/xtool or Linux with Swift/xtool/Darwin SDK supports --ipa.
No Apple/GitHub password is used. The IPA is for an existing signing installer.
"""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import os
import platform
import re
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[1]

def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def source_manifest():
    paths = [p for directory in ('Sources', 'Tests', 'Scripts') for p in (ROOT / directory).rglob('*')
             if p.is_file() and '__pycache__' not in p.parts]
    paths += [ROOT / p for p in ('Package.swift','Package.resolved','xtool.yml','AppIcon.png','Brand.json')]
    paths += list((ROOT / '.github' / 'workflows').glob('*.yml'))
    return {p.relative_to(ROOT).as_posix(): sha(p) for p in sorted(paths)}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ipa', action='store_true')
    parser.add_argument('--python', default=sys.executable)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    run = args.output or ROOT / '.build' / 'verification' / (datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')+'-'+uuid.uuid4().hex[:6])
    run = run.resolve(); run.mkdir(parents=True, exist_ok=False)
    before = source_manifest()
    info = {'sourceFiles': before, 'headAtStart': subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
            'startedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(), 'steps':{},
            'deviceTested':False, 'liveCloudAccountsTested':False, 'signedForInstallation':False}
    report = run / 'verification.json'
    def save(): report.write_text(json.dumps(info,indent=2)+'\n',encoding='utf-8')
    def step(name, command, env=None):
        print(f'{name}: started; full log: {run / (name+".log")}',flush=True)
        with (run/(name+'.log')).open('w',encoding='utf-8') as stream:
            result = subprocess.run(command,cwd=ROOT,env=env,stdout=stream,stderr=subprocess.STDOUT)
        info['steps'][name] = {'command':command,'exitCode':result.returncode,'logSHA256':sha(run/(name+'.log'))}
        save()
        if result.returncode:
            print((run/(name+'.log')).read_text(errors='replace')[-12000:],flush=True)
            raise SystemExit(result.returncode)
        print(f'{name}: passed',flush=True)
        return re.sub(r'\x1b\[[0-9;]*m','',(run/(name+'.log')).read_text(errors='replace'))
    env = dict(os.environ, CALC84_CORE_ONLY='1', C84_FIXTURE_DIR=str(run/'fixtures'))
    core = step('core-tests',['swift','test','-j','4'],env)
    matches = re.findall(r'Executed (\d+) tests?, with 0 failures',core)
    if "Test Suite 'All tests' passed" not in core or not matches: raise SystemExit('Missing successful XCTest summary')
    info['coreTests'] = {'passed':int(matches[-1]),'failed':0}
    recovery = step('recovery-tests',[args.python,'-m','unittest','discover','-s','Scripts','-p','test_recovery.py','-v'],env)
    count = re.search(r'Ran (\d+) tests?',recovery)
    if not count or not re.search(r'^OK$',recovery,re.M): raise SystemExit('Missing successful recovery summary')
    info['independentRecoveryTests'] = {'passed':int(count[1]),'failed':0}
    if args.ipa:
        sdk_version = (subprocess.check_output(['xcrun','--sdk','iphoneos','--show-sdk-version'],text=True).strip()
                       if sys.platform == 'darwin' else '27.1')
        info['buildEnvironment'] = {'host':platform.system(), 'iosSDKVersion':sdk_version,
                                    'swiftVersion':subprocess.check_output(['swift','--version'],text=True).strip()}
        save()
        print(f'iOS SDK: {sdk_version}; host: {platform.system()}',flush=True)
        step('ios-build',['xtool','dev','build','--configuration','release','--ipa'])
        brand = json.loads((ROOT/'Brand.json').read_text())
        ipa = ROOT/'xtool'/(brand['productName']+'.ipa')
        if not ipa.is_file(): raise SystemExit('Native build did not produce the expected IPA')
        info['ipaSHA256'] = sha(ipa)
    if source_manifest() != before: raise SystemExit('Source changed during verification; run again with stable source')
    info['completedAt'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    save()
    if args.ipa:
        subprocess.run([sys.executable,str(ROOT/'Scripts/package_release.py'),'--evidence',str(report)],cwd=ROOT,check=True)
    print(f'Verification: {report}',flush=True)

if __name__ == '__main__': main()
