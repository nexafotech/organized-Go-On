import os
import zipfile
import shutil

def make_zip():
    source_dir = r"C:\Users\Abishek\Desktop\am-oss"
    desktop_onedrive = r"C:\Users\Abishek\OneDrive\Desktop"
    desktop_local = r"C:\Users\Abishek\Desktop"
    
    zip_filename = "originalam.zip"
    dest_zip_onedrive = os.path.join(desktop_onedrive, zip_filename)
    dest_zip_local = os.path.join(desktop_local, zip_filename)

    print(f"Source Directory: {source_dir}")
    print(f"Target Zip (OneDrive Desktop): {dest_zip_onedrive}")
    print(f"Target Zip (Local Desktop): {dest_zip_local}")

    # Excluded directories (relative or directory names)
    exclude_dir_names = {
        ".git",
        ".venv",
        "venv",
        ".pytest_cache",
        "__pycache__",
        ".dart_tool",
        ".idea",
        ".vscode",
    }

    # Special handling for mobile/build:
    # Exclude all mobile/build files except the compiled release APK!
    release_apk_rel = os.path.normpath(r"mobile\build\app\outputs\flutter-apk\app-release.apk")
    release_apk_full = os.path.join(source_dir, release_apk_rel)
    include_release_apk = os.path.exists(release_apk_full)

    temp_zip_path = os.path.join(desktop_onedrive, "originalam_temp.zip")
    if os.path.exists(temp_zip_path):
        os.remove(temp_zip_path)

    total_files = 0
    total_uncompressed_bytes = 0

    with zipfile.ZipFile(temp_zip_path, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as zipf:
        for root, dirs, files in os.walk(source_dir):
            # Prune excluded directories
            rel_root = os.path.relpath(root, source_dir)
            
            # Check if current directory is inside mobile/build
            parts = rel_root.split(os.sep)
            if len(parts) >= 2 and parts[0] == "mobile" and parts[1] == "build":
                dirs[:] = []
                continue

            # Filter dirs in-place
            dirs[:] = [d for d in dirs if d not in exclude_dir_names]

            for file in files:
                ext = os.path.splitext(file)[1].lower()
                if ext in {".pyc", ".pyo", ".log"} and file != "uvicorn_debug.log":
                    continue
                if file.endswith(".tmp") or file.endswith(".crswap"):
                    continue

                full_path = os.path.join(root, file)
                rel_path = os.path.relpath(full_path, source_dir)

                # Skip mobile/build files
                if rel_path.startswith(r"mobile\build") or rel_path.startswith("mobile/build"):
                    continue

                # Top-level folder inside zip: 'originalam'
                arcname = os.path.join("originalam", rel_path)

                zipf.write(full_path, arcname)
                total_files += 1
                total_uncompressed_bytes += os.path.getsize(full_path)

        # Include the pre-built release APK if available
        if include_release_apk:
            print(f"Adding pre-built release APK: {release_apk_rel}")
            arcname = os.path.join("originalam", release_apk_rel)
            zipf.write(release_apk_full, arcname)
            total_files += 1
            total_uncompressed_bytes += os.path.getsize(release_apk_full)

    # Rename temp zip to final zip
    if os.path.exists(dest_zip_onedrive):
        os.remove(dest_zip_onedrive)
    os.rename(temp_zip_path, dest_zip_onedrive)

    # Also copy to local Desktop if different path
    if os.path.normpath(desktop_onedrive) != os.path.normpath(desktop_local):
        if os.path.exists(dest_zip_local):
            os.remove(dest_zip_local)
        shutil.copy2(dest_zip_onedrive, dest_zip_local)

    zip_size_bytes = os.path.getsize(dest_zip_onedrive)
    zip_size_mb = zip_size_bytes / (1024 * 1024)
    uncomp_size_mb = total_uncompressed_bytes / (1024 * 1024)

    print("\n=== Zip Creation Completed Successfully ===")
    print(f"Total files archived: {total_files}")
    print(f"Uncompressed size: {uncomp_size_mb:.2f} MB")
    print(f"Compressed Zip size: {zip_size_mb:.2f} MB")
    print(f"Saved to: {dest_zip_onedrive}")
    if os.path.normpath(desktop_onedrive) != os.path.normpath(desktop_local):
        print(f"Also copied to: {dest_zip_local}")

if __name__ == "__main__":
    make_zip()
