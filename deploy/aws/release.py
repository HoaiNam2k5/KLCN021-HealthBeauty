#!/usr/bin/env python3
"""API/web image-only update. Private snapshots never go to stdout."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

os.umask(0o077)
ROOT = Path(__file__).resolve().parents[2]
STACK = Path('/home/ubuntu/demo-api')
RELEASE_ID = os.environ.get('HEALTHBEAUTY_RELEASE_ID', '20261025-invoice')
if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]{0,79}', RELEASE_ID):
    raise RuntimeError('Invalid release identifier')
RELEASE = STACK / 'releases' / RELEASE_ID
PRIVATE = RELEASE / 'private'
PUBLIC = 'https://healthbeauty.duckdns.org'

def release_services(value=None):
    value = value if value is not None else os.environ.get('HEALTHBEAUTY_RELEASE_SERVICES', 'api,web')
    if value not in ('api', 'api,web'):
        raise RuntimeError('Release services must be api or api,web')
    return value.split(',')

def selected_services(state):
    # Older prepared releases always updated both services.
    return release_services(','.join(state.get('services', ['api', 'web'])))

def image_override(state, key):
    selected = selected_services(state)
    return {'services': {t['service']: {'image': t[key]} for t in state['targets'].values()
                         if t['service'] in selected}}

def run(args, capture=True):
    p = subprocess.run(args, cwd=str(STACK), stdout=subprocess.PIPE if capture else None,
                       stderr=subprocess.PIPE if capture else None, text=True)
    if 'build' in args and args[:3] == ['sudo', '-n', 'docker']:
        PRIVATE.mkdir(mode=0o700, parents=True, exist_ok=True)
        logname = 'build-api.log' if any('Dockerfile.api' in a for a in args) else 'build-web.log'
        (PRIVATE / logname).write_text((p.stdout or '') + (p.stderr or ''))
    if p.returncode:
        # Compose/inspect can contain secrets: report operation, never raw output.
        raise RuntimeError('Command failed: ' + ' '.join(args[:5]))
    return p.stdout if capture else ''

def docker(*args):
    return run(['sudo', '-n', 'docker', *args])

def inspect(name):
    return json.loads(docker('inspect', name))[0]

def save(name, obj):
    PRIVATE.mkdir(mode=0o700, parents=True, exist_ok=True)
    (PRIVATE / name).write_text(json.dumps(obj, indent=2) + '\n')

def compose(files, *args):
    cmd = ['sudo', '-n', 'docker', 'compose', '-p', 'demo-api']
    for f in files:
        cmd += ['-f', f]
    return run(cmd + list(args))

def validate_hashes(value):
    lines = value.splitlines()
    if not lines or any(not re.fullmatch(r'[0-9a-f]{64}  /[^\r\n]+', line) for line in lines):
        raise RuntimeError('Missing or invalid configuration hash manifest')
    return '\n'.join(sorted(lines)) + '\n'


def hashes(container, directory, pattern, image=False):
    prefix = ('run', '--rm', '--network=none', '--read-only', '--entrypoint') if image else ('exec',)
    if image:
        paths = docker(*prefix, 'find', container, directory, '-type', 'f', '-name', pattern, '-print').splitlines()
        if not paths:
            raise RuntimeError('Missing image configuration files')
        value = docker(*prefix, 'sha256sum', container, *sorted(paths))
    else:
        paths = docker(*prefix, container, 'find', directory, '-type', 'f', '-name', pattern, '-print').splitlines()
        if not paths:
            raise RuntimeError('Missing running configuration files')
        value = docker(*prefix, container, 'sha256sum', *sorted(paths))
    return validate_hashes(value)

def env(config):
    return dict(v.split('=', 1) for v in config.get('Env', []) if '=' in v)

def check_config(base, merged, containers, images):
    if set(base['services']) != set(merged['services']):
        raise RuntimeError('Compose service list drift')
    targets = {c['Config']['Labels']['com.docker.compose.service']: name for name, c in containers.items()}
    for service, before in base['services'].items():
        after = merged['services'][service]
        if {k: v for k, v in before.items() if k != 'image'} != {k: v for k, v in after.items() if k != 'image'}:
            raise RuntimeError('Compose changed settings beyond image')
        if service not in targets:
            if before != after:
                raise RuntimeError('Non-target service changed')
            continue
        name = targets[service]
        c, image = containers[name], images[name]['Config']
        future = env(image)
        future.update(after.get('environment', {}))
        if future != env(c['Config']):
            raise RuntimeError('Runtime environment drift: ' + name)
        for d, key in [('Entrypoint', 'entrypoint'), ('Cmd', 'command'), ('WorkingDir', 'working_dir')]:
            desired = after.get(key)
            if desired is None:
                desired = image.get(d)
            if (desired or []) != (c['Config'].get(d) or []):
                raise RuntimeError('Startup drift: ' + name)

def prepare():
    services = release_services()
    if (PRIVATE / 'prepared.json').exists():
        raise RuntimeError('Release already prepared; use activate or a new release directory')
    containers = {name: inspect(name) for name in ['healthbeauty-api', 'healthbeauty-web']}
    api, web = containers.values()
    labels = api['Config']['Labels']
    files = labels.get('com.docker.compose.project.config_files', '').split(',')
    if labels.get('com.docker.compose.project') != 'demo-api' or not files or any(not Path(f).is_file() or Path(f).parent != STACK for f in files):
        raise RuntimeError('Unexpected active Compose files/project')
    app = api['Config']['WorkingDir'].rstrip('/')
    if app != '/app' or api['Config']['Entrypoint'] != ['dotnet', 'HealthBeauty.Api.dll']:
        raise RuntimeError('Unrecognized API startup')
    if web['Config']['Entrypoint'] != ['/docker-entrypoint.sh']:
        raise RuntimeError('Unrecognized web server')
    for name, c in containers.items():
        protected = app if name == 'healthbeauty-api' else '/usr/share/nginx/html'
        for m in c.get('Mounts', []):
            dest = m['Destination'].rstrip('/') or '/'
            if dest == '/' or dest == protected or protected.startswith(dest + '/') or dest.startswith(protected + '/'):
                raise RuntimeError('Mounted application files require a different rollout: ' + name)
    protected = json.loads((RELEASE / 'protected-before.json').read_text())
    for name, digest in protected.items():
        if hashlib.sha256((ROOT / name).read_bytes()).hexdigest() != digest:
            raise RuntimeError('Protected Docker/nginx file changed: ' + name)
    version = time.strftime('%Y%m%d%H%M%S', time.gmtime())
    manifest = {'release': RELEASE_ID}
    state = {'files': files, 'services': services, 'targets': {}, 'untouched': {n: inspect(n)['Id'] for n in ['sqlserver', 'healthbeauty-caddy']},
             'compose_hashes': {f: hashlib.sha256(Path(f).read_bytes()).hexdigest() for f in files}}
    if 'web' not in services:
        state['untouched']['healthbeauty-web'] = web['Id']
    images = {}
    base = json.loads(compose(files, 'config', '--format', 'json'))
    save('compose-before.json', base)
    for name, c in containers.items():
        images[name] = json.loads(docker('image', 'inspect', c['Image']))[0]
        short = 'api' if name == 'healthbeauty-api' else 'web'
        old = 'healthbeauty-' + short + ':before-lifecycle-' + version
        new = 'healthbeauty-' + short + ':lifecycle-' + version
        if short not in services:
            new = old
        docker('tag', c['Image'], old)
        state['targets'][name] = {'id': c['Id'], 'old': old, 'new': new, 'service': c['Config']['Labels']['com.docker.compose.service']}
        save(short + '-container.json', c)
    state['settings'] = hashes('healthbeauty-api', app, 'appsettings*.json')
    image_settings = hashes(state['targets']['healthbeauty-api']['old'], app, 'appsettings*.json', image=True)
    if state['settings'] != image_settings:
        raise RuntimeError('API appsettings changed in container writable layer; preserve first')
    state['nginx'] = hashes('healthbeauty-web', '/etc/nginx', '*')
    image_nginx = hashes(state['targets']['healthbeauty-web']['old'], '/etc/nginx', '*', image=True)
    if state['nginx'] != image_nginx:
        raise RuntimeError('nginx config changed in writable layer; preserve first')
    suffix = '' if RELEASE_ID == '20261025-invoice' else '.' + RELEASE_ID
    override = STACK / ('compose.release' + suffix + '.yaml')
    rollback = STACK / ('compose.rollback' + suffix + '.yaml')
    if override.exists() or rollback.exists():
        raise RuntimeError('Existing release overrides require review; nothing overwritten')
    override.write_text(json.dumps(image_override(state, 'new'), indent=2))
    rollback.write_text(json.dumps(image_override(state, 'old'), indent=2))
    state.update(override=str(override), rollback=str(rollback))
    merged = json.loads(compose(files + [str(override)], 'config', '--format', 'json'))
    check_config(base, merged, containers, images)
    for short in services:
        name = 'healthbeauty-' + short
        target = state['targets'][name]
        print('Building Linux ' + short + ' from approved Git source; production still running.', flush=True)
        docker('build', '--pull=false', '--build-arg', 'RUNTIME_IMAGE=' + target['old'],
               '-f', str(ROOT / 'deploy' / 'aws' / ('Dockerfile.' + short)), '-t', target['new'], str(ROOT))
    # Verify bytes inside newly built images before stopping either running service.
    for short, path in [('api', '/app/HealthBeauty.Api.dll'), ('web', '/usr/share/nginx/html/index.html')]:
        actual = docker('run', '--rm', '--network=none', '--read-only', '--entrypoint', 'sha256sum',
                        state['targets']['healthbeauty-' + short]['new'], path).split()[0]
        manifest[short + '_sha256'] = actual
    manifest['source_commit'] = run(['git', '-C', str(ROOT), 'rev-parse', 'HEAD']).strip()
    save('release.json', manifest)
    save('prepared.json', state)
    print('PREPARED: selected images built; API/web hashed; exact environment/startup/settings preserved; running services unchanged.')

def load():
    return json.loads((PRIVATE / 'prepared.json').read_text())

def untouched(state):
    for name, cid in state['untouched'].items():
        if inspect(name)['Id'] != cid:
            raise RuntimeError('Untouched service ID changed: ' + name)

def probe(path, expected):
    code = run(['curl', '--silent', '--show-error', '--max-time', '15', '-o', '/dev/null', '-w', '%{http_code}', PUBLIC + path])
    if code != str(expected):
        raise RuntimeError('HTTPS probe failed: ' + path + ' HTTP ' + code)

def rollback(state):
    services = selected_services(state)
    untouched(state)
    compose(state['files'] + [state['rollback']], 'up', '-d', '--no-deps', '--no-build', '--pull', 'never', '--force-recreate', *services)
    untouched(state)
    for attempt in range(18):
        try:
            probe('/api/v1/services', 200)
            probe('/', 200)
            break
        except RuntimeError:
            if attempt == 17:
                raise
            time.sleep(2)
    for name, target in state['targets'].items():
        now = inspect(name)
        old = json.loads((PRIVATE / ('api-container.json' if name.endswith('-api') else 'web-container.json')).read_text())
        if now['Image'] != old['Image'] or env(now['Config']) != env(old['Config']):
            raise RuntimeError('Rollback image/environment mismatch')
    if hashes('healthbeauty-api', '/app', 'appsettings*.json') != state['settings'] or hashes('healthbeauty-web', '/etc/nginx', '*') != state['nginx']:
        raise RuntimeError('Rollback configuration mismatch')
    save('rollback-result.json', {'time': time.time(), 'status': 'previous images restored and HTTPS verified'})
    print('ROLLED BACK ' + ','.join(services) + '; existing Compose environment retained.')

def activate():
    state = load()
    services = selected_services(state)
    untouched(state)
    for f, digest in state['compose_hashes'].items():
        if hashlib.sha256(Path(f).read_bytes()).hexdigest() != digest:
            raise RuntimeError('Active Compose files changed since prepare')
    for name, target in state['targets'].items():
        if inspect(name)['Id'] != target['id']:
            raise RuntimeError('Target container changed since prepare')
    if hashes('healthbeauty-api', '/app', 'appsettings*.json') != state['settings']:
        raise RuntimeError('Settings changed since prepare')
    containers = {name: inspect(name) for name in state['targets']}
    images = {name: json.loads(docker('image', 'inspect', t['new']))[0] for name, t in state['targets'].items()}
    base = json.loads((PRIVATE / 'compose-before.json').read_text())
    merged = json.loads(compose(state['files'] + [state['override']], 'config', '--format', 'json'))
    check_config(base, merged, containers, images)
    for name in containers:
        before = json.loads((PRIVATE / ('api-container.json' if name.endswith('-api') else 'web-container.json')).read_text())
        if env(before['Config']) != env(containers[name]['Config']):
            raise RuntimeError('Runtime environment changed during build')
    try:
        compose(state['files'] + [state['override']], 'up', '-d', '--no-deps', '--no-build', '--pull', 'never', '--force-recreate', *services)
        for attempt in range(18):
            try:
                probe('/api/v1/services', 200)
                probe('/', 200)
                break
            except RuntimeError:
                if attempt == 17:
                    raise
                time.sleep(2)
        untouched(state)
        for short in ['api', 'web']:
            name = 'healthbeauty-' + short
            old = json.loads((PRIVATE / (short + '-container.json')).read_text())
            now = inspect(name)
            if env(now['Config']) != env(old['Config']):
                raise RuntimeError('Post-deploy runtime environment mismatch')
        if hashes('healthbeauty-api', '/app', 'appsettings*.json') != state['settings']:
            raise RuntimeError('Post-deploy appsettings mismatch')
        nginx = hashes('healthbeauty-web', '/etc/nginx', '*')
        if nginx != state['nginx']:
            raise RuntimeError('Post-deploy nginx config mismatch')
        manifest = json.loads((PRIVATE / 'release.json').read_text())
        html = subprocess.check_output(['curl', '--fail', '--silent', '--show-error', '--max-time', '15', PUBLIC + '/'])
        if hashlib.sha256(html).hexdigest() != manifest['web_sha256']:
            raise RuntimeError('Public web index does not match release')
        actual_api = docker('exec', 'healthbeauty-api', 'sha256sum', '/app/HealthBeauty.Api.dll').split()[0]
        if actual_api != manifest['api_sha256']:
            raise RuntimeError('Running API does not match built source')
        for name, digest in json.loads((RELEASE / 'protected-before.json').read_text()).items():
            if hashlib.sha256((ROOT / name).read_bytes()).hexdigest() != digest:
                raise RuntimeError('Protected source Docker/nginx file changed')
        for path in re.findall(r'(?:src|href)="(/assets/[^"<>]+)"', html.decode()):
            probe(path, 200)
        probe('/api/v1/invoices', 401)
        save('success.json', {'time': time.time(), 'release': manifest['release'], 'status': 'verified',
                             'container_ids': {name: inspect(name)['Id'] for name in state['targets']}})
        print('DEPLOYED: public HTTPS/services/assets verified; API/web environment and config unchanged; SQL/Caddy unchanged.')
        print('Persistent override: ' + state['override'])
    except Exception:
        print('Activation validation failed; restoring previous selected images.', file=sys.stderr)
        rollback(state)
        raise

if __name__ == '__main__':
    try:
        if sys.argv[1:] == ['prepare']:
            prepare()
        elif sys.argv[1:] == ['activate']:
            activate()
        elif sys.argv[1:] == ['rollback']:
            rollback(load())
        else:
            raise RuntimeError('Usage: python3 deploy.py prepare|activate|rollback')
    except Exception as exc:
        print(type(exc).__name__ + ': ' + str(exc), file=sys.stderr)
        sys.exit(1)
