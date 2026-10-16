import subprocess
import time

def set_theme(theme_mode: str):
    device = 'RZCY935CVJF'
    subprocess.run(['adb', '-s', device, 'shell', 'am', 'force-stop', 'com.aifaceattendance.mobile_app'], check=True)
    time.sleep(0.3)
    
    xml_content = f'''<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <string name="flutter.pref_custom_backend_url">http://192.168.0.150:8000</string>
    <string name="flutter.pref_selected_role_tab">STUDENT</string>
    <string name="flutter.pref_theme_mode">{theme_mode}</string>
</map>
'''
    with open('scripts/theme_temp.xml', 'w', encoding='utf-8') as f:
        f.write(xml_content)
    
    subprocess.run(['adb', '-s', device, 'push', 'scripts/theme_temp.xml', '/data/local/tmp/theme_temp.xml'], check=True)
    subprocess.run(['adb', '-s', device, 'shell', 'chmod 777 /data/local/tmp/theme_temp.xml'], check=True)
    subprocess.run(['adb', '-s', device, 'shell', 'run-as com.aifaceattendance.mobile_app cp /data/local/tmp/theme_temp.xml shared_prefs/FlutterSharedPreferences.xml'], check=True)
    print(f'Successfully persisted flutter.pref_theme_mode to {theme_mode}!')

if __name__ == '__main__':
    import sys
    mode = sys.argv[1] if len(sys.argv) > 1 else 'dark'
    set_theme(mode)
