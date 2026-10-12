import os
from collections import defaultdict

target = "II Year CSE Cyber Security - Class 2"
file_matches = defaultdict(list)

for root, dirs, files in os.walk(r"C:\Users\Abishek\Desktop\am-oss"):
    if any(p in root for p in [".git", "node_modules", "build", ".dart_tool", ".pytest_cache", "__pycache__", ".system_generated"]):
        continue
    for f in files:
        if f.endswith((".py", ".json", ".csv", ".md", ".html", ".js", ".dart", ".sql", ".yaml", ".yml", ".txt")):
            fp = os.path.join(root, f)
            try:
                with open(fp, "r", encoding="utf-8") as fh:
                    for line_idx, line in enumerate(fh, 1):
                        if target in line:
                            rel = os.path.relpath(fp, r"C:\Users\Abishek\Desktop\am-oss")
                            file_matches[rel].append((line_idx, line.strip()))
            except Exception:
                pass

print(f"Total occurrences of '{target}': {sum(len(lines) for lines in file_matches.values())}")
for filepath, lines in sorted(file_matches.items()):
    print(f"=== {filepath} ({len(lines)} occurrences) ===")
    for line_no, content in lines:
        print(f"  Line {line_no:4d}: {content}")
