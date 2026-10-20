# Release Builds Directory (`release/`)

This directory contains standalone compiled production binaries (such as signed/optimized Android APKs) for field testing and distribution.

> [!NOTE]
> Binary application packages (`*.apk`, `*.aab`, `*.ipa`) are excluded from Git repository tracking via `.gitignore` to comply with GitHub's 100MB file limit. Official release binaries are published under [GitHub Releases](https://github.com/nexafotech/go-on-app/releases).

---

## Local APK Hosting

The project provides a built-in HTTP server to download and install built APKs onto physical Android devices over Wi-Fi:
```powershell
python scripts/serve_apk.py --port 8080
```
Then navigate to `http://<your-ip>:8080/` from the device browser or scan the generated QR code.
