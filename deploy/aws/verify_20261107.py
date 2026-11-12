import json
import re
import subprocess
import urllib.request
import urllib.error

base = 'https://healthbeauty.duckdns.org'
def request(path, data=None):
    payload = None if data is None else json.dumps(data).encode()
    req = urllib.request.Request(base + path, data=payload, headers={'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=20) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as error:
        return error.code, error.read()

for path, expected in [('/', 200), ('/api/v1/services', 200), ('/api/v1/invoices', 401), ('/api/v1/service-packages/payments', 401)]:
    status, _ = request(path)
    assert status == expected, f'{path}: {status}'
    print(f'HTTPS {path}: {status}')
status, _ = request('/api/v1/payments/sepay/webhook', {'id': 999999999, 'gateway': 'MBBank', 'accountNumber': 'TEST_ACCOUNT', 'transferType': 'in', 'transferAmount': 1, 'transactionDate': '2026-11-07 08:00:00'})
assert status == 401, f'Webhook auth: {status}'
print('SePay ready and rejects unauthenticated valid payload: 401 (no transaction written)')
_, html = request('/')
script = re.search(rb'src="(/assets/index-[^"]+\.js)"', html).group(1).decode()
_, javascript = request(script)
for name, marker in [('AppointmentsPage', b'appointment-action-trigger'), ('BillingPage', b'payment-detail')]:
    asset = re.search((name + r'-[A-Za-z0-9_-]+\.js').encode(), javascript).group().decode()
    code, content = request('/assets/' + asset)
    assert code == 200 and marker in content, f'Latest page missing: {name}'
    print(f'Latest {name} chunk verified: 200')
containers = json.loads(subprocess.check_output(['sudo', '-n', 'docker', 'inspect', 'healthbeauty-api', 'healthbeauty-web', 'sqlserver', 'healthbeauty-caddy']))
for item in containers:
    print(json.dumps({'name': item['Name'], 'state': item['State']['Status'], 'restartCount': item['RestartCount'], 'id': item['Id'][:12]}))
assert all(item['State']['Running'] for item in containers)
