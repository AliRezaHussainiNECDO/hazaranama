#!/usr/bin/env python3
"""ساخت seed/content.json از فایل‌های بخش‌ها (seed/sections/<section>.json).

هر فایل فهرستی از {"fields": {...}, "image": {...}?} است به ترتیب نمایش. شناسه‌ها پایدارند
(seed-<section>-<n>) تا اجرای دوباره‌ی seed فقط به‌روزرسانی کند، نه تکرار.

«image» (اختیاری): {"src": نشانی فایل در Wikimedia Commons, "credit": نام عکاس و مجوز, "page": صفحه‌ی فایل}
عکس در R2 با کلید commons/<hash>.<ext> آینه می‌شود و از /media/ همین سرور سرو می‌شود.
اجرا:  python3 cloudflare/api/seed/build.py
"""
import hashlib, json, os, glob

PUBLIC = "https://hazaranama-api.alireza-necdo.workers.dev"
here = os.path.dirname(os.path.abspath(__file__))
items, mirror = [], {}
for path in sorted(glob.glob(os.path.join(here, 'sections', '*.json'))):
    sec = os.path.splitext(os.path.basename(path))[0]
    rows = json.load(open(path, encoding='utf-8'))
    for i, r in enumerate(rows, 1):
        it = {"id": f"seed-{sec}-{i:03d}", "section_id": sec, "sort_order": i, "fields": dict(r["fields"])}
        img = r.get("image")
        if img and img.get("src"):
            ext = os.path.splitext(img["src"].split("?")[0])[1].lower() or ".jpg"
            if ext not in (".jpg", ".jpeg", ".png", ".webp"):
                ext = ".jpg"
            key = "commons/" + hashlib.sha1(img["src"].encode()).hexdigest()[:20] + ext
            mirror[key] = img["src"]
            it["image_url"] = f"{PUBLIC}/media/{key}"
            if img.get("credit"):
                it["fields"]["img_credit"] = img["credit"]
            if img.get("page"):
                it["fields"]["img_page"] = img["page"]
        items.append(it)
version = hashlib.sha256(json.dumps(items, ensure_ascii=False, sort_keys=True).encode()).hexdigest()[:16]
json.dump({"version": version, "items": items, "mirror": mirror},
          open(os.path.join(here, 'content.json'), 'w', encoding='utf-8'), ensure_ascii=False)
print(len(items), "items,", len(mirror), "images, version", version)
