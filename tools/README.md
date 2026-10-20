# External Utility Binaries Directory (`tools/`)

This directory is designated for local third-party helper binaries.

> [!NOTE]
> Executable binaries (`*.exe`, `*.bin`) are excluded from Git version control via `.gitignore`.

---

## Supported Tools

### 1. Cloudflared (`cloudflared.exe`)
- **Purpose**: Creates an encrypted outbound zero-trust Cloudflare Tunnel (`trycloudflare.com` / custom hostname) to expose the local FastAPI backend (port 8000) for secure cross-network and mobile device testing without port forwarding.
- **Official Download**: [Cloudflare Tunnel Documentation & Releases](https://github.com/cloudflare/cloudflared/releases)
- **Usage**:
  ```powershell
  tools\cloudflared.exe tunnel --url http://127.0.0.1:8000
  ```
