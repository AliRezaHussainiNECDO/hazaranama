"""واژه‌نامه‌ی هزارگی — بخش «زبان و گویش هزارگی».

هر مدخل: hazaragi, fa, en, cat (دسته)، و در صورت وجود: tr (آوانویسی لاتین)،
example + example_fa (نمونه‌ی کاربرد)، note (توضیح)، src (منبع).

منابع:
- iranica: Encyclopaedia Iranica، مدخل «HAZĀRA iv. Hazāragi dialect» (Charles M. Kieffer)
- wiktionary: Wiktionary (CC BY-SA 4.0) — مدخل‌هایی که برچسب Hazaragi دارند
"""

IR = "دانشنامه‌ی ایرانیکا (Kieffer)"
WK = "ویکی‌واژه (CC BY-SA)"

CATS = [
    "خانواده و خویشاوندی",
    "روستا، طبیعت و کشاورزی",
    "خانه و زندگی روزمره",
    "بدن و صفت‌ها",
    "ضمیرها و دستور زبان",
    "قید و پرسش",
    "فعل‌ها",
    "گفت‌وگوی روزمره",
    "وام‌واژه‌های مغولی و ترکی",
]

def w(hazaragi, fa, en, cat, src, tr=None, example=None, example_fa=None, note=None):
    f = {"hazaragi": hazaragi, "fa": fa, "en": en, "cat": cat, "src": src}
    if tr: f["tr"] = tr
    if example: f["example"] = example
    if example_fa: f["example_fa"] = example_fa
    if note: f["note"] = note
    return f

K, V, H, B, G, Q, F, D, L = CATS

LANG = [
  # ---------------- خانواده و خویشاوندی ----------------
  w("آته / آتی", "پدر", "father", K, WK, tr="āta", note="در ایرانیکا وام‌واژه‌ای ترکی شمرده شده است."),
  w("آبه", "مادر", "mother", K, WK, tr="āba"),
  w("آجه", "مادربزرگ", "grandmother", K, WK, tr="āja"),
  w("تغایی", "مامای، دایی (برادرِ مادر)", "maternal uncle", K, WK, tr="tağāyī"),
  w("آغه", "خواهر بزرگ‌تر (خطاب مهرآمیز)", "older sister (endearing)", K, WK, tr="āğa"),
  w("برار / بیرار", "برادر", "brother", K, WK, tr="birār"),
  w("بیرارو", "برادران", "brothers", K, IR, note="جمع جانداران با «-و» از «-ان» ساخته می‌شود."),
  w("بیری", "عروس", "bride", L, IR, note="وام‌واژه‌ی مغولی."),
  w("بچه‌عمه", "پسرعمه", "father's sister's son", K, IR, note="در جامعه‌ی هزاره خویشاوندی‌ای گرم و مورد اعتماد."),
  w("بچه‌ماما", "پسرِ مامای (پسردایی)", "mother's brother's son", K, IR),
  w("بوله", "پسرخاله", "mother's sister's son", K, IR),
  w("باجه", "باجناق (شوهرِ خواهرِ همسر)", "wife's sister's husband", K, IR),
  w("جیه", "خواهرزاده", "sister's child", K, IR),
  w("خانه‌وار", "تبار، دودمان", "lineage", K, IR),
  w("ریش‌سفید / موی‌سفید", "بزرگِ خانواده یا روستا", "elder", K, IR),
  w("الیجو", "عزیز، دلبر", "dear, sweetheart", K, WK, note="بیشتر در بامیان شنیده می‌شود."),

  # ---------------- روستا، طبیعت و کشاورزی ----------------
  w("آغیل", "قریه، دهکده‌ی کوچک", "village, hamlet", V, WK, tr="āğil"),
  w("چپری", "کلبه، خانه‌ی کوچک (در شمال هزارستان)", "hut, small house", V, IR),
  w("ییلاق", "چراگاه تابستانیِ مرتفع", "summer pasture", V, IR),
  w("قشلاق", "سکونتگاه زمستانی در دره", "winter quarters", V, IR),
  w("للمی", "زمین یا کشتِ دیم (بی‌آبیاری)", "rain-fed cultivation", V, IR),
  w("ترماهی", "گندم پاییزه", "autumn wheat", V, IR),
  w("قُلبه", "شخم؛ زمینِ شخم‌زده", "ploughing; ploughed field", V, IR),
  w("پوشُم", "پشم", "wool", V, IR),
  w("بلک", "برگ", "leaf", V, WK, tr="balk"),
  w("سیو", "سیب", "apple", V, WK, tr="sēw"),
  w("اُشتر", "شتر", "camel", V, WK, tr="uštur"),
  w("طنو", "طناب، ریسمان", "rope", V, WK, tr="tanaw"),

  # ---------------- خانه و زندگی روزمره ----------------
  w("منبر", "تکیه‌خانه‌ی روستا: نمازخانه، تالار و مهمان‌خانه", "village prayer and meeting hall", H, IR),
  w("جاغه", "یقه", "collar", H, WK, tr="jāğa"),
  w("گُدی", "عروسک", "doll", H, WK, tr="guḍī"),
  w("گُدی‌پران", "بادبادک", "kite", H, WK, tr="guḍīparān"),
  w("ایلک / الک", "غربال، الک", "sieve", H, WK, tr="ēlak"),
  w("جنتری", "تقویم، سالنامه", "calendar, almanac", H, WK, tr="jantarī"),
  w("با", "بها، قیمت", "price", H, WK, tr="bā"),
  w("قومندان", "فرمانده‌ی نظامی محلی", "(militia) commander", H, IR),

  # ---------------- بدن و صفت‌ها ----------------
  w("چِم / چیم", "چشم", "eye", B, WK, tr="čim"),
  w("الغه", "کفِ دست", "palm of the hand", L, IR, note="وام‌واژه‌ی مغولی."),
  w("کټه / کته", "بزرگ، کلان؛ و نیز پیر", "big, large; old", B, WK, tr="kaṭa"),
  w("کلوتر", "بزرگ‌تر", "bigger", B, IR),
  w("غدر", "زیاد، بسیار", "much, a lot", B, WK, tr="ğadar", note="ویژه‌ی هزارگی؛ احتمالاً از ترکی یا مغولی."),
  w("قره", "سیاه", "black", L, IR, note="وام‌واژه‌ی ترکی."),
  w("دیده", "شتاب، عجله", "haste, hurry", B, WK),
  w("اټاله", "تخمین، حدس", "estimate, guess", B, WK, tr="aṭāla"),

  # ---------------- ضمیرها و دستور زبان ----------------
  w("ما / تو", "من / تو", "I / you (sg.)", G, IR),
  w("مو / شیمو", "ما / شما", "we / you (pl.)", G, IR),
  w("یو / وو", "این‌ها / آن‌ها", "these / those (they)", G, IR, note="از «ای‌ها» و «او‌ها»."),
  w("او", "آن", "that, it", G, WK),
  w("مره", "مرا", "me (object)", G, WK),
  w("خوت", "خود، خویش", "self, own", G, IR),
  w("کُدَم", "کدام؛ و نیز «کسی»", "which; someone", G, IR),
  w("کتابو", "کتاب‌ها", "books", G, IR, note="نشانه‌ی جمع «-و» از «-ها» آمده است."),
  w("-قتی", "همراهِ، با (پسوند همراهی)", "together with", G, IR),
  w("کتی", "همراهِ، با", "with", G, WK, tr="katī", example="کتی از وا موری؟", example_fa="با آن‌ها می‌روی؟"),
  w("-وری / واری", "مانندِ، مثلِ", "like, as", G, IR),
  w("اَدلی", "مانندِ، مثلِ", "like", G, WK),
  w("خون / خونی", "با، به‌وسیله‌ی", "with, by means of", G, IR),
  w("دَ", "در؛ و اغلب به‌جای «به»", "in; to", G, IR),
  w("ډَل", "گروه، دسته", "group", G, IR),

  # ---------------- قید و پرسش ----------------
  w("چکه", "چرا؟", "why?", Q, WK, tr="čika"),
  w("ایقه", "این‌قدر", "this much", Q, WK, tr="īqa"),
  w("اینجی / اونجی", "این‌جا / آن‌جا", "here / there", Q, IR),
  w("ایسو", "این‌سو، این‌جا", "here, this way", Q, WK, tr="īsō"),
  w("جه", "جا", "place", Q, WK),
  w("اولی", "اکنون، حالا", "now", Q, IR),
  w("وخته", "آن‌وقت، سپس", "then", Q, IR),
  w("شایتی", "شاید", "perhaps", Q, IR),
  w("بایتی", "باید، لازم است", "it is necessary", Q, IR),
  w("آتی / اَرِی", "بله، آری", "yes", Q, IR),

  # ---------------- فعل‌ها ----------------
  w("نیه", "نیست", "is not", F, WK, example="اینجی نیه", example_fa="این‌جا نیست"),
  w("کد", "کرد", "did", F, WK),
  w("مـ (پیشوند فعل)", "مـی (نشانه‌ی استمرار)", "continuous prefix", F, WK, example="چی مخری؟", example_fa="چه می‌خوری؟"),
  w("می‌زنُم", "می‌زنم", "I hit / I am hitting", F, IR),
  w("نمی‌زدُم", "نمی‌زدم", "I was not hitting", F, IR),
  w("زدیم", "زده‌ام (گزارشی و نادیده)", "(apparently) I have hit", F, IR, note="این ساخت برای رویدادی به کار می‌رود که گوینده خودش ندیده است."),
  w("خوت (فعل کمکی)", "نشانه‌ی احتمال: «شاید بشود»", "potential marker", F, IR, note="از «خواهد»."),
  w("تانِستن", "توانستن", "to be able", F, IR),
  w("کدگی", "انجام‌شده، کرده‌شده", "having been done", F, IR),

  # ---------------- گفت‌وگوی روزمره ----------------
  w("چی مخری؟", "چه می‌خوری؟", "what are you eating?", D, WK),
  w("کتی از وا موری؟", "با آن‌ها می‌روی؟", "are you going with them?", D, WK),
  w("اینجی نیه", "این‌جا نیست", "it isn't here", D, WK),
  w("پیسه پیشُم نیه", "پول پیشم نیست", "I have no money on me", D, WK),

  # ---------------- وام‌واژه‌های مغولی و ترکی ----------------
  w("قلغی", "دزد", "thief", L, IR, note="وام‌واژه‌ی مغولی."),
  w("اوغو", "افغان (پشتون)", "Afghan (Pashtun)", L, WK, tr="awğō"),
]

assert all(f["cat"] in CATS for f in LANG)
