#!/usr/bin/env python3
"""ساخت seed/content.json از فایل‌های بخش‌ها (seed/sections/<section>.json).

هر فایل فهرستی از {"fields": {...}} است به ترتیب نمایش. شناسه‌ها پایدارند
(seed-<section>-<n>) تا اجرای دوباره‌ی seed فقط به‌روزرسانی کند، نه تکرار.
اجرا:  python3 cloudflare/api/seed/build.py
"""
import json, os, glob
here = os.path.dirname(os.path.abspath(__file__))
items = []
for path in sorted(glob.glob(os.path.join(here, 'sections', '*.json'))):
    sec = os.path.splitext(os.path.basename(path))[0]
    rows = json.load(open(path, encoding='utf-8'))
    for i, r in enumerate(rows, 1):
        items.append({"id": f"seed-{sec}-{i:03d}", "section_id": sec, "sort_order": i, "fields": r["fields"]})
import hashlib
version = hashlib.sha256(json.dumps(items, ensure_ascii=False, sort_keys=True).encode()).hexdigest()[:16]
json.dump({"version": version, "items": items}, open(os.path.join(here, 'content.json'), 'w', encoding='utf-8'), ensure_ascii=False)
print(len(items), "items", "version", version)
