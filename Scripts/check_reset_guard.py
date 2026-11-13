"""Prove the reset tests reject an inverted identity guard; always restore source."""
from pathlib import Path
import json
import os
import re
import subprocess

root = Path(__file__).resolve().parents[1]
source = root / 'Sources/CalcCore/VaultRepository.swift'
original = source.read_bytes()
guard = b'guard try identifier() == expectedID else { throw VaultError.changed }'
assert original.count(guard) == 1
output = root / '.build/native-validation'
output.mkdir(parents=True, exist_ok=True)
log = output / 'reset-guard-mutation.log'
try:
    source.write_bytes(original.replace(guard, guard.replace(b'==', b'!=')))
    with log.open('w', encoding='utf-8') as stream:
        result = subprocess.run(['swift', 'test', '-j', '4', '--filter', 'VaultResetTests'],
                                cwd=root, env=dict(os.environ, CALC84_CORE_ONLY='1'),
                                stdout=stream, stderr=subprocess.STDOUT)
finally:
    source.write_bytes(original)
assert source.read_bytes() == original
text = log.read_text(encoding='utf-8', errors='replace')
detected = result.returncode != 0 and re.search(r'Executed 2 tests?, with [1-9][0-9]* failures?', text) is not None
(output / 'reset-guard-mutation.json').write_text(json.dumps({
    'invertedIdentityGuardRejected': detected, 'sourceRestored': True,
    'testProcessExitCode': result.returncode
}, indent=2) + '\n')
if not detected:
    print(text[-5000:])
    raise SystemExit('Reset tests did not demonstrate rejection of the inverted guard')
print('Reset tests rejected the inverted identity guard; original source restored.')
