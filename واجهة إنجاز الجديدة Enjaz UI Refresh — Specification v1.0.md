# واجهة إنجاز الجديدة | Enjaz UI Refresh — Specification v1.0

Prepared for Mohamed Gamal — 7 Nov 2026 — Save this file in the repository root as UI.md.

> ملاحظة بالعربي: الملف ده مستقل ومش تكملة لأي ملف تاني. بيغيّر الشكل والتنقل بس: صفحة رئيسية بكروت لكل قسم، وتنقل أنظف، وستايل أهدى. من غير أي تغيير في السلوك أو البيانات. مكتوب بالإنجليزي عشان الوكيل، ونصوص الواجهة بالعربي. لو أي حاجة مش واضحة اسألني في الشات.

## 0. Instructions to the AI coding agent (read first)

1. This file is standalone. SPEC.md, CHANGES.md and VOICE.md describe the features of the app. This file changes the LOOK and the NAVIGATION only. If it conflicts with them about layout or navigation, this file wins. About everything else, they win.
2. The owner is NOT a programmer. Talk to him in simple Egyptian Arabic and give every action he must take as short numbered steps.
3. Work in the steps of section 9, one at a time. After each step: tests, README.md, CHANGELOG.md, DECISIONS.md, commit, tag (ui-1, ui-2...), CI build, a plain-Arabic test checklist, and wait for approval.
4. Do NOT change behavior, data, database schema, permissions, reminders or business rules. No new libraries unless asked. All text goes through ARB files. All colors, sizes and radii come from the tokens of section 3.
5. The owner will attach images: a grid mockup and two reference screens (Home and More, 390 x 844). They are a visual reference only. The Arabic text inside the mockup is garbled, and it shows things that are NOT part of this work (sleep and steps, a profile photo, a search bar and filters, neon glow). This file wins over the images.
6. Every APK must install over the previous one (same signing key, higher version).
7. Be honest about what you could not check on a real device. Ask the owner for screenshots from his phone (light and dark) after each step.
8. Keep: light and dark themes, Arabic RTL and English LTR, font scale up to 1.3x, accessibility rules of SPEC.md section 10.

## 1. Decisions (agreed with the owner)

| Topic | Decision |
| --- | --- |
| Style | Calm and minimal: thin borders instead of glow or neon, same brand teal as today. |
| Home | A grid of cards: one full-width Today card, then half-width cards in two columns. |
| Navigation | 4 bottom tabs plus a center '+' button. 'المزيد' only for utilities. |
| Greeting | 'أهلاً، \<name>' with a name from Settings. No photo. |
| Not included | Sleep and steps, global search and filters, profile photo, Android home-screen widgets, any new data feature. |
| Cards | Each card can be hidden and moved. |

## 2. Problems to fix (seen in the owner's screenshots)

1. Secondary text is too dim: the date under the day name on Today, and the descriptions in More. Contrast must reach 4.5:1.
2. More has two similar history entries ('التقويم والسجل الزمني' and 'السجل الزمني للمهام'). This is confusing.
3. More starts with a large 'إنجاز' card that does nothing.
4. The main modules (Habits, Finance, Health, Calendar) are buried in More, so the owner gets lost.
5. The first screen shows only tasks, and it is empty and plain when there are none.

## 3. Design tokens

Keep the current brand teal and the dark and light backgrounds of SPEC.md section 3. Change only what is listed here.

| Token | Light | Dark |
| --- | --- | --- |
| background | #FAFAF9 | #0F1412 |
| card | #FFFFFF | #1A1F1E |
| inner surface | #F5F5F4 | #232928 |
| text | #1C1917 | #F5F5F4 |
| text-secondary | #57534E | #A8A29E |
| border | #E7E5E4 | #2F3534 |
| accent | #0D9488 | #2DD4BF |
| warning text | #92400E | #FBBF24 |
| warning border | #F59E0B | #5C4410 |

- text-secondary replaces text-muted for any text that carries information (dates, descriptions, labels). Minimum text size is 12.
- A pure Dart contrast function plus a unit test: every text and background pair of these tokens must reach 4.5:1 (3:1 for text of 24 px and above), in both themes.
- Typography: Cairo for Arabic, Inter for English. Greeting 22/700, card title 15/600, key value 22/700, body 14, caption 12. Line height 1.4 to 1.5.
- Spacing on a 4-point grid. Screen margin 16, gap between cards 12, card padding 16, card radius 16, inner radius 12, chips fully rounded.
- Borders 1 px from the token. No shadows, no glow, no gradients. Focus ring 2 px accent.
- Icons: outlined, stroke 2, sizes 18, 22 and 24. Motion 150 to 250 ms, no looping animation.
- Shared widgets (one implementation each, used everywhere): AppCard, CardHeader (title and an optional link), ProgressBar (6 px), MiniRing, StatValue, StatusChip, EmptyState, AppBottomBar (with the center button), QuickAddMenu.

## 4. The Home screen (الرئيسية)

From top to bottom. Reference width 390. Everything is read from the existing services through one new summary service, HomeSummaryService, with lightweight aggregated queries and reactive updates. No heavy work on the UI thread.

**4.1 Header.** 'أهلاً، \<name>' and today's date in words (for example 'السبت ٧ نوفمبر ٢٠٢٦'), in text-secondary. If no name is set, show 'أهلاً'. A settings button on the end side. When the voice assistant of VOICE.md exists, its microphone button sits next to it.

**4.2 Cards.**

| Card | Width | Shows | Tap opens |
| --- | --- | --- | --- |
| النهارده | Full | 'N من M تمت' for today, a progress bar, and the next unfinished task with its time (if none has a time, the first unfinished one). If everything is done: a short done message. | The Tasks page (the current Today screen with its date switcher). |
| العادات | Half | A ring with habits completed out of habits scheduled today, and the number of consecutive days on which all scheduled habits were completed (ending today, or yesterday while today is not complete). No habits yet: a short empty state with an 'إضافة عادة' button. | Habits. |
| المال | Half | Spending today in large type. Below it: the remaining monthly budget if an overall budget exists, otherwise 'مصروف الشهر ده: X'. Amounts are masked with the finance eye icon. | Finance. |
| الصحة | Half | The nearest appointment or needed item (title and day). If none: 'مفيش مواعيد قريبة'. A chip 'N مؤجل' when postponed items exist. | Health. |
| الأهداف والأفكار | Half | 'N أهداف نشطة', and 'N أفكار · N ملاحظات'. | The Plan tab. |
| متأخر | Full strip | Only when overdue tasks exist: 'N مهمة متأخرة' with a link, in the warning colors. | The overdue list on the Tasks page. |

**4.3 Layout rules.**

- Half-width cards pair up in the order the owner set. An odd one out becomes full width.
- Below 360 px of width, half-width cards become full width.
- At font scale 1.3 cards grow in height and text wraps. Nothing is clipped or overlaps.
- The screen scrolls if the cards do not fit. Each card has loading, empty and error states, and respects the privacy toggles.

**4.4 Privacy.** A setting 'إخفاء تفاصيل الصحة في الرئيسية' (default OFF): when ON, the Health card shows only 'موعد قادم' without the title. Finance amounts follow the existing masking.

## 5. Navigation

- **Bottom bar:** الرئيسية | التخطيط | (center '+' button) | الإحصائيات | المزيد. The old 'اليوم' tab becomes the Tasks page, opened from the Today card.
- **The '+' button** opens a bottom sheet 'إضافة' with: مهمة، مشوار، مصروف، عادة (log), ملاحظة، فكرة، and 'تسجيل صوتي' when the voice assistant exists. Each opens the existing add sheet or screen.
- **التخطيط:** the existing segments أهداف | أفكار | ملاحظات.
- **الإحصائيات:** the existing screen. The calendar and timeline of CHANGES.md Round 7 open from its top bar.
- **المزيد** contains only: الإعدادات، النسخ الاحتياطي والأمان، تقرير إكسيل، السجل، سلة المحذوفات. The large app card is removed. The duplicate history entry is removed: السجل is the list of tasks and history, and the calendar and timeline open from Stats.
- A module whose Home card is hidden appears in More, so it is never unreachable.
- Back from any module returns to the Home screen.

## 6. Module screens (Step 3)

Apply the same header, cards, spacing, empty states and secondary text to: Tasks page, Plan (goals, ideas, notes), Stats, Habits, Finance, Health, Calendar and timeline, History, Trash, Settings. One screen at a time. Layout may be tidied, but every action, field and rule stays exactly as it is.

## 7. Settings changes

- Settings > الملف الشخصي: 'الاسم' (optional text).
- Settings > الرئيسية: show or hide each card, move each card up or down, and the Health privacy toggle of 4.4.
- No other setting changes.

## 8. Rules (not negotiable)

1. No change to behavior, data or schema. No new permission.
2. No hardcoded colors, sizes or text. Tokens and ARB only.
3. Light and dark, RTL and LTR, font scale 1.3 must all work on every changed screen.
4. The Home summary uses aggregated queries. No query inside list builders. Unit tests for HomeSummaryService (the streak rule, the next-task rule, the budget rule).
5. Every card has loading, empty and error states.

## 9. Build steps

- **Step 1 — Tokens and shared widgets:** the tokens, the contrast test, the shared widgets, and applying the tokens to the existing screens WITHOUT changing layouts.
- **Step 2 — Home and navigation:** HomeSummaryService, the Home screen, the bottom bar with the center button and the add menu, the Tasks page, the cleaned More screen, and the settings of section 7.
- **Step 3 — Screens one by one:** section 6, one screen per prompt.

After each step: screenshots from the owner's phone (light and dark, before and after), tests, tag, CI APK that installs over the previous one.

## 10. Acceptance tests (the owner, on his phone)

1. The Home screen shows the greeting with his name, the date, and the cards in the agreed layout, in both themes.
2. Tapping each card opens its module. Back returns to Home.
3. The numbers on the cards equal the numbers inside the modules.
4. Hiding the Finance card puts Finance in More. Showing it again removes it from More.
5. The '+' menu opens every add screen.
6. The overdue strip appears only when a task is overdue.
7. Secondary text is readable in both themes (the date under the day name, the descriptions in More).
8. At the largest font size nothing is clipped on Home.
9. With the Health privacy toggle ON, the Health card hides the title.
10. The new APK installs over the previous one with the data intact.

## 11. Risks and open items

- Arabic text with large fonts can wrap badly. Check Home at font scale 1.3 on a small phone.
- A Home screen with many cards can feel crowded again. Keep to the five cards and the strip.
- The mockup images are generated, so they are not exact. Use this file for content and the images for mood only.
- Open items for the owner: confirm the card order, and whether to add a short quick-stat line under the greeting later.

## 12. Kickoff message (the owner pastes one per step)

> ابدأ من UI.md فقط. نفّذ الخطوة N فقط (القسم 9). اقرأ القسمين 0 و8 مع أقسام الخطوة. اعمل خطة قصيرة بالعربي وانتظر موافقتي، وبعدها نفّذ. ما تبدأش خطوة تانية، وأي حاجة مش واضحة اسألني فيها. في الآخر: شغّل الاختبارات، حدّث README وCHANGELOG وDECISIONS، اعمل commit وtag باسم ui-N وRelease رسمي للـ APK، وادّيني خطوات التجربة على موبايلي مع طلب لقطات شاشة قبل وبعد.
