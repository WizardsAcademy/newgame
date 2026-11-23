# پرامپت کامل: تکمیل نوآ (Noa) — از صفر تا هیرو تموم‌شده

> هدف: حداقل **یک** هیرو کامل. نوآ رو کامل می‌کنیم، بعد سراغ بقیه می‌ریم.

---

## ۰. وضعیت واقعی — قبل از اینکه کاری کنی این رو بخون

من همه‌چیز رو اندازه گرفتم. مشکل نوآ **کد نیست**. این‌ها ثابت شده‌ست:

| چیز | نتیجه |
|---|---|
| پایپ‌لاین ایمپورت | درسته و idempotent — دوباره اجرا کنی بایت‌به‌بایت همون چیز درمیاد |
| پالت | ۲۳ از ۲۴ رنگ — تمیز |
| فرینج | ۷۹۶ پیکسل حذف شد — درست کار می‌کنه |
| **مشکل اصلی** | **آرت دستی کشیده شده، نه پیکسل‌آرت** |

اثباتش (این عددها رو خودم درآوردم):

- آرت نوآ **۴,۰۸۸ رنگ** داره. شوالیه ۱۹ رنگ.
- اگه پیکسل‌آرت واقعی باشه، بلوک‌های ۲×۲ باید یکدست باشن. نوآ: **۴.۶٪** یکدست. شوالیه: **۴۰.۵٪**.
- بلوک ۳×۳: نوآ **۰.۵٪** / شوالیه **۱۹.۷٪**.
- هیچ گرید پیکسلی پنهانی وجود نداره — تست کردم، دورهٔ غالب = ۲ پیکسل یعنی «جزئیات هر ۲ پیکسل»، نه گرید.
- کوچک کردن (downsample) هم نجاتش نمی‌ده: /۲ → ۱,۰۱۸ رنگ، /۴ → ۲۳۶ رنگ، هنوز کثیف.

**یعنی چی؟** نوآ با براش نرم (anti-aliased) کشیده شده. وقتی ایمپورت می‌شه، هر لبه تبدیل می‌شه به یه نوار خاکستری/بنفش چندرنگ. تو بازی با `scale 0.5` روی صفحه **۴۸ پیکسل** می‌شه — یه لکهٔ تیره. اینو نمی‌شه با کد درست کرد. باید دوباره کشیده بشه.

---

## ۱. باگ‌هایی که در کد بود و الان درست شده

این‌ها تقصیر آرت نبود، تقصیر خودِ پایپ‌لاین بود. پَچش هست: `docs/patches/noa_animation_fix.patch`

| انیمیشن | قبل (روی main) | بعد |
|---|---|---|
| `attack` | f13 (لانج) → f11 (ضربه) → **f2 که یه فریم راه‌رفتنه!** | f0 → f11 → f12 |
| `walk_down` | آیدل رو از وسط نصف می‌کرد، هر نیمه رو ۲px بالا می‌برد → **درز عرضی روی بدن** | دو پوز واقعی روبرو |
| `hurt` | یه فریم راه‌رفتن رو عمودی ۰.۹ فشرده + ۳px کج می‌کرد → **لکهٔ خاکستری** | پوز کشیده‌شدهٔ recoil + ۱px هول |
| `die` | آیدل رو **۷۶- درجه می‌چرخوند** بعد به ۵۶×۲۵ کوچیک می‌کرد → **بدون‌شکل** | بدن فرو می‌ره پشت یه استخر خون |
| `walk` | ۴ فایل مختلف که هیچ ربطی به هم نداشتن، مثل فازهای سایکل | یک پوز واقعی + آینهٔ پایین‌تنه + فریم contact |

اثرش: `docs/images/noa_animation_fix.png`

**ولی این کافی نیست.** چون فقط باگ کد بود. مشکل `walk` هنوز سر جاشه: پوز سمت‌نما واقعاً دو تا پا نداره که عوض بشن. آینه که می‌کنی، خونۀ شنل تکون می‌خوره نه پا. برای همین باید پاها کشیده بشن.

---

## ۲. دو باگی که هنوز هست

**باگ الف — نوآ شناوره.** روی هر ۱۶ فریم، ردیف ۸۰ (همون `ground_y`) **صفر** پیکسل داره. پاش تا y=79 می‌رسه، ولی سایه روی ۸۰ نشسته. یعنی ۱ پیکسل تو هواست. تو بازی این دیده می‌شه.

**باگ ب — چرخهٔ راه‌رفتن وجود نداره.** `walk.png` فقط یه پوز چپ‌نماست. `another walk .png`، `anothr walk.png`، `anoter walk.png`، `walk 2.png` — همه چپ‌نما و همه تقریباً یه چیز. **هیچ‌کدوم یه قدم واقعی نیست.**

---

## ۳. پرامپت آماده — کپی کن بده به ابزار تصویر

> این پرامپت برای تولید **یک شیت پوز** طراحی شده که مستقیم بره تو پایپ‌لاین.

```
Create a 96x96 pixel art character pose sheet, transparent background.
This is a game sprite, NOT concept art, NOT an illustration.

SUBJECT
Vampire queen "Noa". Young female, gothic aristocrat. Long pale
lavender-silver hair falling past the waist, center-parted with a
straight blunt fringe. Small dark iron crown with 3 spikes. Deep red
glowing eyes, thick dark eyeliner. Pale cool skin. Black high-collared
dress with a crimson underlayer, a fitted bodice, and a long floor-length
skirt with a slit. Dark iron bracers. Small pointed ears.
Style benchmark: Dead Cells and Hollow Knight. Gothic, elegant, deadly.
NOT cute. NOT chibi. NOT kawaii. NOT anime-shaded.

CRITICAL TECHNICAL RULES — follow these exactly
1. Hard pixel edges ONLY. Every pixel must be a solid flat colour.
2. NO anti-aliasing. NO soft brush. NO blur. NO gradients. NO dithering.
3. MAXIMUM 24 colours total across the whole sheet.
4. Draw at 1:1 pixel scale. Do not draw large and shrink.
5. Character is ~68 pixels tall. Feet rest on row 79. Row 80 is empty.
6. Body faces FOUR directions: front, back, left side, right side.
7. Left and right are TRUE 3/4 views, not the front pose mirrored.
8. Outline is dark desaturated purple (#2B1F33). NEVER pure black.
9. Lighting from upper-left. Light on shoulders and hair crown,
   dark on the underside of the skirt and under the hair.

WHAT TO DRAW — 12 poses, arranged in a 4x3 grid, each cell 96x96
Row 1: idle front, idle back, idle side-left, idle side-right
Row 2: walk front A, walk front B, walk side A, walk side B
Row 3: attack windup, attack strike, hurt recoil, death collapse

WALK CYCLE — this is the most important part
The side walk A and B must be TWO DIFFERENT LEG POSITIONS:
  A = left leg forward and planted, right leg back, heel lifted
  B = right leg forward and planted, left leg back, heel lifted
The legs must be SEPARATED and VISIBLE below the skirt hem.
The hem must lift and swing with the stride. Do NOT hide the legs.
Both poses must have BOTH feet touching row 79.

ANATOMY CHECK
Head height = about 1/5 of total height (not 1/3 — no big anime head).
Shoulders narrow. Waist visible. Two clearly separate legs.
Silhouette must be readable as a solid black shape at 48 pixels tall.
```

---

## ۴. اگه خودت می‌کشی (نه AI) — این‌ها رو رعایت کن

**بوم:** ۹۶×۹۶. شفاف. `ground_y = 80`.

**ارتفاع بدن:** دقیقاً ۶۸ پیکسل. یعنی سرِ مو از y=12 شروع می‌شه، کفش روی y=79.

**پالت (همون ۲۴ رنگ فعلی، دست نزن):**

| نقش | رنگ |
|---|---|
| خط دور | `#2B1F33` |
| مو روشن | `#E8DCF0` |
| مو متوسط | `#C4B0D4` |
| مو سایه | `#8E7DA6` |
| پوست | `#F2E4E8` |
| پوست سایه | `#D4B8C4` |
| مشکی لباس | `#1A1520` |
| لباس تیره | `#3A2C42` |
| زرشکی | `#8B1A32` |
| زرشکی تیره | `#5C0F22` |
| قرمز چشم | `#D42040` |
| طلایی | `#C9A227` |
| فلز تاج | `#4A3F55` |

**قانون‌های سخت:**
- براش Pencil، اندازه ۱، **بدون** anti-alias. اگه برنامه‌ات alpha-blend داره، خاموشش کن.
- هیچ پیکسلی با آلفای بین ۰ و ۲۵۵ نباید باشه. یا کامل یا هیچ.
- خط دور هیچ‌وقت `#000000` نباشه — از `#2B1F33` استفاده کن.
- سایه‌زنی: فقط ۳ تُن در هر ناحیه. سایه از بالا-چپ.
- پاها: **باید** روی y=78 و y=79 حداقل ۲ ردیف پیکسل داشته باشن. این تنها راه اینکه شناور نباشه.

**چک‌لیست قبل از ذخیره:**
```
[ ] ارتفاع بدن = 68 پیکسل
[ ] کفش روی ردیف 79، ردیف 80 خالی
[ ] رنگ‌ها ≤ 24
[ ] هیچ آلفای نیمه‌شفاف (غیر 0 و 255)
[ ] پاها جدا و قابل دیدن
[ ] سیلوئت در 48px هنوز خوانا
[ ] خط دور مشکی خالص نیست
```

---

## ۵. ترتیب کار — دقیقاً همین ترتیب

**مرحله ۱ — پاها.** فقط یه چیز بکش: پوز سمت‌نما با پاهای جدا. یه `walk.png` جدید که دو تا پا داشته باشه و شنل جلوشون رو نپوشونه. این تنهایی ۵۰٪ مشکل رو حل می‌کنه.

**مرحله ۲ — ایمپورت و اندازه‌گیری.**
```bash
python3 tools/import_pose_sheet.py --hero noa
python3 tools/measure_hero_sheets.py
```
باید ببینی: `body_height=68`، `ground_y={80}`، `colours=23`، `semi_alpha=0.00%`.

**مرحله ۳ — باگ شناور بودن.** اگه ردیف ۸۰ خالی بود، تو `place_pose_in_cell` این خط رو عوض کن:
```python
# از:
dest_y = ground_y - sh
# به:
dest_y = min(ground_y - sh, ground_y - 1)
```
این تضمین می‌کنه پایین‌ترین پیکسل روی ۷۹ بشینه.

**مرحله ۴ — چرخهٔ راه‌رفتن.** با پوز جدید، `make_mirrored_stride` کار می‌کنه چون پاها جدا هستن. فریم‌های ۲،۳،۴،۵ خودشون سایکل می‌شن.

**مرحله ۵ — پوزهای اضافه.** `attack windup` (f13) که الان افتاده، `hurt` واقعی، `die` واقعی.

**مرحله ۶ — یکسان‌سازی.** وقتی نوآ تموم شد، ارتفاعش ۶۸ پیکسله. بقیه باید بیان به همون: بهمات ۶۰ (باید ۶۸ بشه)، نایت ۷۲→۶۸، سیلوارا ۶۱→۶۸.

---

## ۶. پَچ آماده

```bash
git apply docs/patches/noa_animation_fix.patch
python3 tools/import_pose_sheet.py --hero noa
```

این ۴ انیمیشن کد رو درست می‌کنه. **آرت رو درست نمی‌کنه** — برای اون مرحله ۱ و ۵ لازمه.

---

## ۷. یه چیز که باید بدونی

بعد از این کار، اگه خواستی کیفیت بقیه هیروها هم بالا بره: **مشکل همشون یکیه**. هر چهار تا با روش‌های مختلف کشیده شده‌ن و هیچ کدوم پیکسل‌آرت خالص نیست. `docs/HERO_SKELETON_SPEC.md` و `tools/hero_skeleton_check.py` توی PR #25 هنوز هستن — می‌تونی برگردونی که دوباره گیت بذاره.
