"""Package only application source/assets; never include configuration credentials."""
from pathlib import Path
import hashlib
import json
import re
import tarfile

ROOT = Path(__file__).resolve().parents[2]
OUT = Path('D:/KhoaLuan/_Work/release-20261107-admin-mobile')
OUT.mkdir(parents=True, exist_ok=True)
files = []
for folder in ['HealthBeauty.Api', 'HealthBeauty.Web/src', 'HealthBeauty.Web/public', 'deploy/aws']:
    for path in (ROOT / folder).rglob('*'):
        rel = path.relative_to(ROOT)
        if not path.is_file() or any(part in {'bin', 'obj', 'node_modules', '__pycache__', 'Properties'} for part in rel.parts):
            continue
        if folder == 'HealthBeauty.Api' and path.suffix not in {'.cs', '.csproj'}:
            continue
        if folder == 'deploy/aws' and path.name not in {'release.py', 'test_release.py', 'Dockerfile.api', 'Dockerfile.web'}:
            continue
        if path.name.startswith('.env') or path.suffix in {'.pem', '.key', '.jks', '.keystore', '.pfx'} or 'firebase-adminsdk' in path.name:
            raise RuntimeError('Forbidden file: ' + str(rel))
        files.append(path)
for name in ['.dockerignore', 'HealthBeauty.Web/package.json', 'HealthBeauty.Web/package-lock.json', 'HealthBeauty.Web/index.html', 'HealthBeauty.Web/vite.config.ts', 'HealthBeauty.Web/tsconfig.json', 'HealthBeauty.Web/tsconfig.app.json', 'HealthBeauty.Web/tsconfig.node.json', 'HealthBeauty.Web/eslint.config.js']:
    files.append(ROOT / name)
for path in files:
    if path.suffix in {'.cs', '.ts', '.tsx', '.json'}:
        source = path.read_text(encoding='utf-8-sig')
        if re.search(r'-----BEGIN (?:RSA |OPENSSH )?PRIVATE KEY-----|AIza[0-9A-Za-z_-]{30,}|(?i:(?:Password|Pwd)=[^;\s\"\']{4,};)', source):
            raise RuntimeError('Potential embedded credential: ' + str(path.relative_to(ROOT)))
manifest = {str(path.relative_to(ROOT)).replace('\\', '/'): hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted(set(files))}
(OUT / 'source-manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
archive = OUT / 'source.tgz'
with tarfile.open(archive, 'w:gz') as bundle:
    for path in sorted(set(files)):
        bundle.add(path, arcname=str(path.relative_to(ROOT)).replace('\\', '/'))
print(json.dumps({'files': len(manifest), 'archive': str(archive), 'bytes': archive.stat().st_size, 'sha256': hashlib.sha256(archive.read_bytes()).hexdigest()}))
