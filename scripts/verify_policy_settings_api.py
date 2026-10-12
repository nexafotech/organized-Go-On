import urllib.request
import json

def main():
    print("=" * 60)
    print("VERIFYING LIVE ADMIN POLICY & SETTINGS API")
    print("=" * 60)

    # 1. Login as admin
    login_data = json.dumps({'username_or_email': 'admin', 'password': 'admin123'}).encode()
    req = urllib.request.Request('http://127.0.0.1:8000/api/v1/auth/login', data=login_data, headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req) as res:
        token = json.loads(res.read().decode())['access_token']
    print("1. Admin Login: OK, Token obtained")

    # 2. GET attendance policy
    req_get = urllib.request.Request('http://127.0.0.1:8000/api/v1/admin/settings/attendance-policy', headers={'Authorization': f'Bearer {token}'})
    with urllib.request.urlopen(req_get) as res:
        pol = json.loads(res.read().decode())
    print("2. GET Policy calculation_mode:", pol.get('calculation_mode'))
    assert pol['calculation_mode'] in ['RECORD_BASED', 'IMPACT_BASED'], f"Invalid calculation_mode: {pol.get('calculation_mode')}"

    # 3. PUT attendance policy with RECORD_BASED
    put_data = json.dumps({'minimum_percentage': 75.0, 'calculation_mode': 'RECORD_BASED'}).encode()
    req_put = urllib.request.Request('http://127.0.0.1:8000/api/v1/admin/settings/attendance-policy', data=put_data, headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}, method='PUT')
    with urllib.request.urlopen(req_put) as res:
        updated = json.loads(res.read().decode())
    print("3. PUT RECORD_BASED:", updated['calculation_mode'])
    assert updated['calculation_mode'] == 'RECORD_BASED'

    # 4. PUT attendance policy with IMPACT_BASED
    put_data2 = json.dumps({'minimum_percentage': 75.0, 'calculation_mode': 'IMPACT_BASED'}).encode()
    req_put2 = urllib.request.Request('http://127.0.0.1:8000/api/v1/admin/settings/attendance-policy', data=put_data2, headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}, method='PUT')
    with urllib.request.urlopen(req_put2) as res:
        updated2 = json.loads(res.read().decode())
    print("4. PUT IMPACT_BASED:", updated2['calculation_mode'])
    assert updated2['calculation_mode'] == 'IMPACT_BASED'

    # 5. Revert back to RECORD_BASED
    req_put3 = urllib.request.Request('http://127.0.0.1:8000/api/v1/admin/settings/attendance-policy', data=put_data, headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}, method='PUT')
    with urllib.request.urlopen(req_put3) as res:
        reverted = json.loads(res.read().decode())
    print("5. Reverted back to:", reverted['calculation_mode'])
    assert reverted['calculation_mode'] == 'RECORD_BASED'

    # 6. Check /admin static page served (requires auth)
    req_admin = urllib.request.Request('http://127.0.0.1:8000/admin', headers={'Authorization': f'Bearer {token}'})
    with urllib.request.urlopen(req_admin) as res:
        html = res.read().decode()
    assert 'id="policyCalcMode"' in html, "id='policyCalcMode' not in /admin HTML"
    assert 'value="RECORD_BASED">Record Based<' in html, "Record Based option not in HTML"
    assert 'value="IMPACT_BASED">Impact Based<' in html, "Impact Based option not in HTML"
    assert 'EXACT_PERCENTAGE' not in html, "Old EXACT_PERCENTAGE still present in HTML!"
    print("6. Admin Panel HTML served with correct dropdown options and no legacy EXACT_PERCENTAGE!")

    # 7. Check /static/js/admin_app.js served
    with urllib.request.urlopen('http://127.0.0.1:8000/static/js/admin_app.js') as res:
        js = res.read().decode()
    assert "RECORD_BASED" in js
    assert "IMPACT_BASED" in js
    assert "isSavingPolicy" in js
    assert "existingToasts" in js
    print("7. Static JS served with deduplication and calculation_mode mapping!")

    print("=" * 60)
    print("ALL LIVE VERIFICATION CHECKS PASSED!")
    print("=" * 60)

if __name__ == '__main__':
    main()
