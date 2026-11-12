from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import tarfile
import os

os.umask(0o077)
stack = Path('/home/ubuntu/demo-api')
release = stack / 'releases/20261107-admin-mobile'
if release.exists():
    raise RuntimeError('Release path already exists; inspect before retrying')
archive = Path('/home/ubuntu/healthbeauty-20261107-source.tgz')
if hashlib.sha256(archive.read_bytes()).hexdigest() != '2ed48c73018782dbd34bbb27821f94a68d0994ef46de28cd5f179b2575916f24':
    raise RuntimeError('Archive hash mismatch')
source = release / 'source'
source.mkdir(parents=True)
with tarfile.open(archive) as bundle:
    for member in bundle.getmembers():
        if member.issym() or member.islnk() or not (source / member.name).resolve().is_relative_to(source):
            raise RuntimeError('Unexpected archive member')
    bundle.extractall(source)
protected = {}
for name in ['HealthBeauty.Api/Dockerfile', 'HealthBeauty.Web/Dockerfile', 'HealthBeauty.Web/nginx.conf']:
    original = stack / 'source' / name
    target = source / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(original, target)
    protected[name] = hashlib.sha256(original.read_bytes()).hexdigest()
(release / 'protected-before.json').write_text(json.dumps(protected, indent=2))
for args in [['git', 'init', '-q'], ['git', 'add', '.'], ['git', '-c', 'user.name=HealthBeauty Deployment', '-c', 'user.email=deploy@healthbeauty.invalid', 'commit', '-q', '-m', 'Approved local source snapshot 20261107']]:
    subprocess.run(args, cwd=source, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
print('STAGED: verified source archive; protected Docker/nginx copied unchanged; canonical server source untouched.')
