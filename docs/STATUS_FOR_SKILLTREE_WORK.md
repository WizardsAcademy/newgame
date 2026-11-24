# وضعیت پروژه — برای کار روی Skill Tree و Combat

`origin/main` = `62c2356` (Merge PR #31)

---

## ۱. جواب مستقیم: merge کردی یا نه؟

**بله، خودت merge کردی.** هر دو PR.

| PR | تاریخ merge | وضعیت |
|---|---|---|
| #30 | 2026-11-23 19:21 | ✅ MERGED (خودت) |
| #31 | 2026-11-23 23:31 | ✅ MERGED (خودت) |

از این دو تا به بعد، **هیچ PR دیگه‌ای merge نشده** و `main` همون `62c2356` مونده.

**تنها PR باز: #25** — که مال خودمه و `CONFLICTING` ئه. دلیلش اینه که GitHub تاریخ `main` رو squash کرده (فقط ۱ کامیت داره)، پس merge-base مشترک نداریم.

---

## ۲. مهم: من یه اشتباه کردم و باید تصحیح کنم

تو پیام قبلی نوشتم که skill tree «فقط UI» ئه. **این غلط بود** و باید عذر بخوام.

بعدش رفتم کد رو خط به خط خوندم. `apply_to_hero_instance()` واقعاً وجود داره و `main.gd` خط ۲۷۹ صداش می‌زنه. **کار می‌کنه.**

ولی چیزهایی که گفتم درست بود:
- ❌ `HUD` عدد skill رو نشون نمی‌ده
- ❌ `max_health` توی HUD آپدیت نمی‌شه
- ⚠️ منطق اسکیل یه‌جا متمرکزه (`witch_cauldron_progression.gd` خط ۴۶۰ به بعد)، نه توی هیروها — یعنی هر هیرو جدید باید بره همون‌جا کیس اضافه کنه

---

## ۳. چی الان آماده‌ست (برای کار امروزت)

### ✅ Skill Tree — کامل و کارکننده

`scripts/progression/witch_cauldron_progression.gd` (۱۸.۷ KB)

```
ساختار: 1 → 3 → 6 → 6  (۱۶ نود، Lv 0..5)
Row 0: vitality
Row 1: wrath, focus, essence
Row 2: blade, swiftness, heart, ward, burst, reaper
Row 3: mastery_0..5   (قفل‌شده تا وقتی parent ≥ 1)
```

**هر ۱۶ نود اثر واقعی دارن:**

| نود | اثر |
|---|---|
| vitality | +12 Max HP / lv |
| wrath | +3 Attack DMG / lv |
| focus | +8 Max Energy, +15% regen / lv |
| essence | مخصوص هر هیرو |
| blade | +2 weapon DMG / lv |
| swiftness | +7 Move Speed, +14 Dash Speed / lv |
| heart | +10 Max HP / lv |
| ward | +6 Max HP + کاهش دمیج / lv |
| burst | +3 Special DMG / lv |
| reaper | +2 ATK, +6 Max Energy / lv |
| mastery_* | tier 4، قفل |

**مخصوص هر هیرو (essence):**
- **Knight** → `armor_flat_reduction +1`, `dash_damage +4`
- **Sylvara** → `charged_arrow_damage +5`, `max_energy +12`
- **Noa** → `heal_per_enemy_hit +1`, `splash_range +8`
- **Behemoth** → `dash_damage +4`

**نقطهٔ ضعف مهم:** `essence` برای هر هیرو یه `match` جدا داره. یعنی هر بار هیرو جدید بسازی، باید بری همون فایل رو ویرایش کنی. **این مقیاس‌پذیر نیست.**

### ✅ UI منو
`scripts/ui/witch_skill_tree_menu.gd` (۳۰.۵ KB) — تم رنگی اختصاصی هر هیرو، conduits، padlock، inspector dock.

### ✅ Wave / Enemy
`scripts/enemies/wave_spawner.gd` (۲۸۲ خط):
```
base_count = 4, +1 per wave
hp_per_wave = +10
speed_per_wave = +5
boss هر ۵ wave
archer از wave 3 (30%)
golem از wave 5 (15%)
elite از wave 6 (8% + 2%/wave, سقف 25%)
```

### ✅ Ability — هر ۴ هیرو مکانیک متفاوت دارن

| هیرو | مکانیک |
|---|---|
| **Behemoth** | حملهٔ ۳ حالته (عادی/cross/uppercut) + موج uppercut |
| **Knight** | سپر با انرژی (`armor_flat_block`)، exhaustion، stance |
| **Sylvara** | کمان charge، تیر piercing، charge ring |
| **Noa** | Blood Splash (HP می‌ده به جای انرژی)، bat swarm، nova |

---

## ۴. چی **نیست** — و اینا مشکل واقعی‌ان

### ❌ ۱. حالت «سبک بازی» وجود نداره

`docs/VISION.md` و `docs/ROADMAP.md` رو چک کردم. «Bazi sabk» به معنی یه **difficulty / style mode** (مثل Easy/Normal/Hard یا Casual/Standard) **هیچ کدی نداره**.

`user://witch_cottage_save.cfg` فقط این‌ها رو ذخیره می‌کنه:
- `profile/selected_hero`
- `skills_<hero>/*`
- `settings/master_volume`, `sfx_volume`, `screen_shake`, `fullscreen`

**هیچ preset سختی، هیچ modifier، هیچ انتخاب سبک.**

### ❌ ۲. دمیج توی HUD دیده نمی‌شه

اسکیل که می‌گیری، `attack_damage` عوض می‌شه، ولی بازیکن **هیچ‌جا نمی‌بینه**. نه توی منو، نه توی HUD. یعنی حس پیشرفت صفره.

### ⚠️ ۳. مقیاس‌پذیری اسکیل

همون‌طور که گفتم، `essence` یه `match hid:` ئه. برای ۱۰ هیرو می‌شه ۱۰ کیس توی یه فایل ۱۸ کیلوبایتی.

### ⚠️ ۴. `_get_bonus_speed_multiplier()` توی base خالیه

`player_base.gd` خط ۳۶: `return 1.0` — هیچ‌وقت عوض نمی‌شه. فقط Sylvara override می‌کنه. یعنی اگه بخوای skill روی سرعت اثر بذاره از این مسیر، باید عوضش کنی.

---

## ۵. کاری که پیشنهاد می‌کنم برای امروز

به ترتیب اولویت:

**۱. HUD راست‌گو کن (نیم ساعت).** وقتی skill می‌گیری، یه پاپ‌آپ «ATK 18 → 21» بده. الان `_spawn_status_popup("SKILL UP!")` هست ولی عدد نداره. این تنها کاریه که «حس» پیشرفت رو می‌سازه.

**۲. یه فایل `hero_skills.gd` بساز (۱ ساعت).** به جای `match hid:` توی ۳ جا، یه دیکشنری:
```gdscript
const ESSENCE_EFFECTS := {
    "knight":   {"armor_flat_reduction": [1, 0], "dash_damage": [4, 0]},
    "sylvara":  {"charged_arrow_damage": [5, 0], "max_energy": [12.0, 0.0]},
    "noa":      {"heal_per_enemy_hit": [1, 0], "splash_range": [8.0, 0.0]},
    "behemoth": {"dash_damage": [4, 0]},
}
```
بعد هیرو جدید = یک خط. همه‌چیز دیگه خودکار.

**۳. حالت سبک بازی (۲-۳ ساعت).** یه enum ساده:
```gdscript
enum Style { CASUAL, STANDARD, BRUTAL }
```
که `hp_per_wave`, `damage_step`, `count_per_wave` رو ضرب می‌کنه. توی Settings یه دکمه.

---

## ۶. یه هشدار

قبل از اینکه روی skill tree و combat کار کنی، **باگ‌های merge #30/#31 رو بدون**. مخصوصاً:

- **شوالیه ۷ پیکسل می‌پره** وقتی از idle به walk می‌ره (فریم ۹ → ۱۰)
- **نوآ موقع مرگ یه بیضی قرمز** می‌شه
- **قلب نوآ روی سرشه** در ۱۶ فریم از ۱۶

اگه روی combat کار کنی و اینا بمونن، هر بار تست کنی گیج می‌شی. جزئیات توی `docs/MERGE_30_31_REVIEW.md`.

---

## ۷. خلاصهٔ یک‌خطی

Skill tree، wave، enemy، ability — **همه کار می‌کنن**. حالت «سبک بازی» **وجود نداره** و باید ساخته بشه. دمیج توی HUD نشون داده نمی‌شه که بزرگ‌ترین نقطهٔ ضعف طراحی‌ه.
