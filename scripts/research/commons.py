#!/usr/bin/env python3
"""Find freely licensed Wikimedia Commons images for Hazaranama content.

Input:  scripts/research/targets.json
  [{"id": "...", "wiki": ["Enwiki title", ...], "search": ["commons query", ...], "files": ["File:..."], "n": 4}]
Output (in ./out): candidates.json + thumbs/<id>-<k>.jpg (small previews for review)
Only Commons-hosted files with a free licence (CC0 / PD / CC BY / CC BY-SA) are kept.
"""
import json, os, re, sys, time, urllib.parse, urllib.request, html

UA = "HazaranamaBot/1.0 (https://hazaranama.com; alireza.necdo@gmail.com)"
OUT = "out"
os.makedirs(f"{OUT}/thumbs", exist_ok=True)


def get(url, retries=3):
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=40) as r:
                return r.read()
        except Exception as e:  # noqa
            if i == retries - 1:
                print("FAIL", url[:120], e, file=sys.stderr)
                return None
            time.sleep(2 + i * 3)


def api(base, **params):
    params.setdefault("format", "json")
    params.setdefault("formatversion", "2")
    raw = get(base + "?" + urllib.parse.urlencode(params))
    return json.loads(raw) if raw else {}


COMMONS = "https://commons.wikimedia.org/w/api.php"
FREE = re.compile(r"^(cc0|public domain|pd|cc[ -]by(-sa)?[ -]?\d|cc by(-sa)? \d|cc-by(-sa)?-\d|attribution|gfdl)", re.I)


def strip(s):
    s = re.sub(r"<[^>]+>", "", s or "")
    return html.unescape(re.sub(r"\s+", " ", s)).strip()


def lead_image(wiki_title, lang="en"):
    d = api(f"https://{lang}.wikipedia.org/w/api.php", action="query", prop="pageimages", piprop="name", titles=wiki_title, redirects=1)
    pages = d.get("query", {}).get("pages", [])
    for p in pages:
        if p.get("pageimage"):
            return "File:" + p["pageimage"]
    return None


def search_files(q, n):
    d = api(COMMONS, action="query", list="search", srsearch=f"{q} filetype:bitmap", srnamespace=6, srlimit=n)
    return [h["title"] for h in d.get("query", {}).get("search", [])]


def info(titles):
    if not titles:
        return []
    d = api(COMMONS, action="query", prop="imageinfo", iiprop="url|extmetadata|size|mime", iiurlwidth=1280, titles="|".join(titles))
    out = []
    for p in d.get("query", {}).get("pages", []):
        if p.get("missing") or not p.get("imageinfo"):
            continue
        ii = p["imageinfo"][0]
        m = ii.get("extmetadata", {})
        lic = strip(m.get("LicenseShortName", {}).get("value", ""))
        if not FREE.match(lic) or "nc" in lic.lower().replace("cc0", ""):
            continue
        if ii.get("mime") not in ("image/jpeg", "image/png", "image/webp"):
            continue
        out.append({
            "file": p["title"],
            "page": ii.get("descriptionurl"),
            "url": ii.get("thumburl") or ii.get("url"),
            "w": ii.get("width"), "h": ii.get("height"),
            "author": strip(m.get("Artist", {}).get("value", ""))[:160],
            "license": lic,
            "license_url": strip(m.get("LicenseUrl", {}).get("value", "")),
            "desc": strip(m.get("ImageDescription", {}).get("value", ""))[:300],
            "date": strip(m.get("DateTimeOriginal", {}).get("value", ""))[:40],
        })
    return out


def main():
    if not os.path.exists("scripts/research/targets.json"):
        return
    targets = json.load(open("scripts/research/targets.json", encoding="utf-8"))
    result = {}
    for t in targets:
        tid, n = t["id"], t.get("n", 4)
        titles = list(t.get("files", []))
        for w in t.get("wiki", []):
            lang = "en"
            if w.startswith("fa:"):
                lang, w = "fa", w[3:]
            f = lead_image(w, lang)
            if f and f not in titles:
                titles.append(f)
        for q in t.get("search", []):
            for f in search_files(q, n + 2):
                if f not in titles:
                    titles.append(f)
        cands = []
        for i in range(0, len(titles), 40):
            cands += info(titles[i:i + 40])
        # keep order of discovery
        order = {f: i for i, f in enumerate(titles)}
        cands.sort(key=lambda c: order.get(c["file"], 999))
        cands = cands[: max(n, 1) + 2]
        for k, c in enumerate(cands):
            c["k"] = k
            small = re.sub(r"/\d+px-", "/330px-", c["url"]) if "/thumb/" in c["url"] else c["url"]
            data = get(small)
            if data:
                open(f"{OUT}/thumbs/{tid}-{k}.jpg", "wb").write(data)
            time.sleep(0.3)
        result[tid] = cands
        print(tid, len(cands), file=sys.stderr)
    json.dump(result, open(f"{OUT}/candidates.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)

    # optional: link checks
    if os.path.exists("scripts/research/links.json"):
        links = json.load(open("scripts/research/links.json", encoding="utf-8"))
        res = {}
        for url in links:
            try:
                req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 " + UA})
                with urllib.request.urlopen(req, timeout=30) as r:
                    body = r.read(200000).decode("utf-8", "ignore")
                    t = re.search(r"<title[^>]*>(.*?)</title>", body, re.S | re.I)
                    res[url] = {"status": r.status, "final": r.geturl(), "title": strip(t.group(1))[:200] if t else ""}
            except urllib.error.HTTPError as e:
                res[url] = {"status": e.code}
            except Exception as e:  # noqa
                res[url] = {"status": 0, "error": str(e)[:120]}
            time.sleep(0.5)
        json.dump(res, open(f"{OUT}/links.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()


def books():
    """Search archive.org and Google Books for each library title."""
    if not os.path.exists("scripts/research/books.json"):
        return
    res = {}
    for b in json.load(open("scripts/research/books.json", encoding="utf-8")):
        r = {"archive": [], "google": []}
        d = get("https://archive.org/advancedsearch.php?" + urllib.parse.urlencode(
            {"q": b["q"], "fl[]": ["identifier", "title", "creator", "year", "mediatype", "licenseurl"], "rows": 6, "output": "json"}, doseq=True))
        if d:
            try:
                for x in json.loads(d)["response"]["docs"]:
                    r["archive"].append(x)
            except Exception:
                pass
        d = get("https://www.googleapis.com/books/v1/volumes?" + urllib.parse.urlencode({"q": b["g"], "maxResults": 4}))
        if d:
            try:
                for x in json.loads(d).get("items", []):
                    vi = x.get("volumeInfo", {})
                    r["google"].append({"title": vi.get("title"), "authors": vi.get("authors"), "date": vi.get("publishedDate"),
                                        "publisher": vi.get("publisher"), "link": vi.get("infoLink"), "lang": vi.get("language"),
                                        "access": x.get("accessInfo", {}).get("viewability")})
            except Exception:
                pass
        res[b["id"]] = r
        time.sleep(0.5)
    json.dump(res, open(f"{OUT}/books.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    books()


def wiki():
    """Search English Wikipedia and return intro extracts, to confirm facts and cite articles."""
    if not os.path.exists("scripts/research/wiki.json"):
        return
    res = {}
    for w in json.load(open("scripts/research/wiki.json", encoding="utf-8")):
        d = api("https://en.wikipedia.org/w/api.php", action="query", list="search", srsearch=w["q"], srlimit=3)
        hits = [h["title"] for h in d.get("query", {}).get("search", [])]
        out = []
        if hits:
            e = api("https://en.wikipedia.org/w/api.php", action="query", prop="extracts|info", inprop="url", exintro=1, explaintext=1,
                    titles="|".join(hits), redirects=1)
            pages = {p["title"]: p for p in e.get("query", {}).get("pages", [])}
            for h in hits:
                p = pages.get(h)
                if p:
                    out.append({"title": p["title"], "url": p.get("fullurl"), "extract": (p.get("extract") or "")[:1500]})
        res[w["id"]] = out
        time.sleep(0.3)
    json.dump(res, open(f"{OUT}/wiki.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    wiki()


def pages():
    """Save full plain text of selected Wikipedia pages for offline fact-checking."""
    if not os.path.exists("scripts/research/pages.json"):
        return
    os.makedirs(f"{OUT}/pages", exist_ok=True)
    for t in json.load(open("scripts/research/pages.json", encoding="utf-8")):
        d = api("https://en.wikipedia.org/w/api.php", action="query", prop="extracts|info", inprop="url", explaintext=1, titles=t, redirects=1)
        for p in d.get("query", {}).get("pages", []):
            txt = (p.get("fullurl") or "") + "\n\n" + (p.get("extract") or "")
            # wikitext too (tables in list pages are dropped by extracts)
            w = api("https://en.wikipedia.org/w/api.php", action="parse", page=p.get("title", t), prop="wikitext", redirects=1)
            txt += "\n\n=====WIKITEXT=====\n" + (w.get("parse", {}).get("wikitext", "") if isinstance(w.get("parse", {}).get("wikitext"), str) else "")
            open(f"{OUT}/pages/{re.sub(r'[^A-Za-z0-9]+', '_', t)[:80]}.txt", "w", encoding="utf-8").write(txt)
        time.sleep(0.5)


if __name__ == "__main__":
    pages()
