import os
import re

pattern = re.compile(r'II Year CSE Cyber Security - Class 1')
found = []

for root, dirs, files in os.walk(r"C:\Users\Abishek\Desktop\am-oss"):
    if any(p in root for p in [".git", "node_modules", "build", ".dart_tool", ".pytest_cache", "__pycache__", ".system_generated"]):
        continue
    for f in files:
        if f in ["find_class2_references.py", "inspect_and_update_db_class2.py", "audit_class2_literal.py", "audit_class1_intact.py"]:
            continue
        if f.endswith((".py", ".json", ".csv", ".md", ".html", ".js", ".dart", ".sql", ".yaml", ".yml", ".txt")):
            fp = os.path.join(root, f)
            try:
                with open(fp, "r", encoding="utf-8") as fh:
                    for line_idx, line in enumerate(fh, 1):
                        if pattern.search(line):
                            rel = os.path.relpath(fp, r"C:\Users\Abishek\Desktop\am-oss")
                            found.append((rel, line_idx, line.strip()))
            except Exception:
                pass

print(f"Total occurrences of 'II Year CSE Cyber Security - Class 1' intact: {len(found)}")
