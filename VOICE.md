<!-- PAGE 1 -->
Voice Assistant — | اﻟﺼﻮﺗﻲ  اﻟﻤﺴﺎﻋﺪ
Specification v1.0
Prepared for Mohamed Gamal — 7 Nov 2026 — Save this file in the repository root as
VOICE.md.
ﻣﺴﺎﻋﺪ:  ﺑﺲ  واﺣﺪة  ﻣﻴﺰة  ﺑﻴﻮﺻﻒ.  CHANGES.md ﻟـ  ﺗﻜﻤﻠﺔ  وﻣﺶ  ﻣﺴﺘﻘﻞ  ده  اﻟﻤﻠﻒ:  ﺑﺎﻟﻌﺮﺑﻲ  ﻣﻼﺣﻈﺔ
ﻣﻜﺘﻮب.  إﻧﺘﺮﻧﺖ  ﻏﻴﺮ  وﻣﻦ  اﺻﻄﻨﺎﻋﻲ  ذﻛﺎء  ﻏﻴﺮ  ﻣﻦ  ﻣﺤﻠﻴﺔ،  ﺑﻘﻮاﻋﺪ  ﺑﻴﺸﺘﻐﻞ  اﻟﺘﻄﺒﻴﻖ  ﺟﻮه  ﺻﻮﺗﻲ
ﻟﺄﻧﻬﺎ  اﻟﻤﺼﺮي  ﺑﺎﻟﻌﺮﺑﻲ  واﻟﺄﺳﺌﻠﺔ  اﻟﺄواﻣﺮ  وﺟﻤﻞ  ﺑﺪﻗﺔ،  ﻳﻔﻬﻤﻪ(  Antigravity) اﻟﻮﻛﻴﻞ  ﻋﺸﺎن  ﺑﺎﻟﺈﻧﺠﻠﻴﺰي
.اﻟﺸﺎت  ﻓﻲ  اﺳﺄﻟﻨﻲ  واﺿﺤﺔ،  ﻣﺶ  ﺣﺎﺟﺔ  أي  ﻟﻮ.  ﻓﻌﻼً  ﻫﺘﺘﻘﺎل  اﻟﻠﻲ
0. Instructions to the AI coding agent (read first)
1. This file is standalone. SPEC.md and CHANGES.md describe the app that already
exists (its modules and services). This file adds ONE feature. If this file conflicts with
them about the voice assistant, this file wins. About everything else, they win. Any
earlier idea of an AI or cloud assistant has been dropped: there is none.
2. The owner is NOT a programmer. Talk to him in simple Egyptian Arabic. Give every
action he must take as short numbered steps.
3. Work in the steps of section 12, one step at a time. After each step: run all tests,
update README.md, CHANGELOG.md and DECISIONS.md, commit, tag (voice-1,
voice-2...), let CI build the APK, give a plain-Arabic test checklist for that step, and
wait for approval.
4. Do not add anything outside this file. If something is unclear, or you want a different
approach, stop and ask first with 2 or 3 options and a recommendation.
5. Never wipe or reset user data. Any database change is a NEW Drift migration with a
test.
6. No INTERNET permission, no networking library, no AI or LLM call, no analytics. The
only external pieces are the Android platform speech recognizer and the Android
text-to-speech engine, used through platform APIs.
7. Reuse the existing services and repositories. Every write made by voice goes through
the same code as the manual screens (status rules, reminder scheduling, events, soft
delete). Do not copy business logic.
8. Be honest about what depends on the phone (speech recognition accuracy, offline
behavior, Arabic voice for speech output on Xiaomi). Measure it, report the numbers,
and never claim a result you did not measure.
9. Every new APK must install over the previous one (same signing key, higher version).
اﻟﻤﺴﺎﻋﺪ اﻟﺼﻮﺗﻲ | Voice Assistant — Speciﬁcation v1.0
Page 1 of 13

<!-- PAGE 2 -->
1. What the owner wants (agreed)
Speak commands to record things instead of typing: tasks, errands, reminders,
expenses, income, habit logs, notes, ideas, wishlist items, health items. Also speak
status changes: done, postponed with a reason, waiting, stopped, partial.
Ask questions and get answers from his own data: what is ahead today, tomorrow, in
two days or on a weekday; what he did yesterday, last week, this month or on a given
date; spending questions; habit questions; what is overdue, postponed, waiting.
It does not have to be AI. The idea must work, locally and predictably.
The app will be published to other people later. This local design needs no API key, has
no per-user cost, and sends no data anywhere, so it is also ready for publishing.
2. The experience (what the owner sees and hears)
2.1 Entry points. A microphone button in the Today top bar, an item in More, and an
Android app shortcut (long-press the app icon) named 'ﺑﺎﻟﺼﻮت  ﺳﺠّﻞ / Voice'. All open the
same screen: the assistant sheet.
2.2 The assistant sheet. A large microphone button, a live transcript area, a text field (so
the same parser also accepts typed sentences), suggestion chips ('ﻋﻤﻠﺖ', ' اﻟﻨﻬﺎرده؟  إﻳﻪ  وراﻳﺎ
ﻣﺼﺮوف  ﺳﺠّﻞ', ' اﻣﺒﺎرح؟  إﻳﻪ ,)'and the result area.
2.3 Flow.
1. Tap the microphone: a short vibration, a sound wave, and the transcript appears live.
2. Tap again to stop (maximum 60 seconds).
3. Understanding is instant and local. The result is one of three things: a Confirmation
card (a command), an Answer card (a question), or 'Not understood'.
Decision Choice
Starting and stopping Tap to start listening, tap again to stop
Confirmation card Confirmed by tap OR by voice (say 'ﺗﻤﺎم 'or 'إﻟﻐﺎء)'
Replies to questions Text card plus spoken reply
Commands per sentence One
Deleting by voice Not available
Languages Egyptian Arabic first, English later as an option
Internet Not used by the app
اﻟﻤﺴﺎﻋﺪ اﻟﺼﻮﺗﻲ | Voice Assistant — Speciﬁcation v1.0
Page 2 of 13

<!-- PAGE 3 -->
2.4 Confirmation card. Shows the interpreted action in plain words with every field, for
example: دﻗﺎﻳﻖ  10 ﻗﺒﻠﻬﺎ  ﻣﻨﺒﻪ —  م  5:00 — ﻧﻮﻓﻤﺒﺮ  8 اﻟﺄﺣﺪ' —  اﻟﻌﻤﻴﻞ  أﻛﻠﻢ — ' ﻣﻬﻤﺔ .Buttons: ﺗﺄﻛﻴﺪ/ 
Confirm, ﺗﻌﺪﻳﻞ / Edit (opens the normal pre-filled quick-add sheet), إﻟﻐﺎء / Cancel. After
Confirm, the normal Undo snackbar appears.
Voice confirmation: when a card appears, the microphone listens for a short window
(default 5 seconds, a visible indicator shows it). The words أﻳﻮه  ﻣﺎﺷﻲ،  ﺗﺄﻛﻴﺪ،  أﻛﺪ،  ﺗﻤﺎم،
confirm. The words ﺳﻴﺒﻚ  ﻻ،  ﻟﺄ،  إﻟﻐﺎء، cancel. The word ﺗﻌﺪﻳﻞ opens the edit sheet.
Anything else is ignored. Voice confirmation applies to the latest card only and can be
switched off in Settings.
Dates and times are always shown in words on the card, and amounts in digits with
the currency, because speech recognition is weakest on numbers.
2.5 Answer card. A title (for example 'ﻧﻮﻓﻤﺒﺮ  7 اﻟﺴﺒﺖ —  اﻟﻨﻬﺎرده ,)'sections with icons and
counts, and buttons that open the matching screen (the day or period in the timeline, the
finance screen, and so on). The same answer is spoken with text-to-speech when spoken
replies are on.
2.6 Missing or ambiguous information.
No date spoken for a task: the card shows the chips ﺗﺎرﻳﺦ  اﺧﺘﺮ /  ﺗﺎرﻳﺦ  ﺑﺪون /  ﺑﻜﺮة /  اﻟﻴﻮم,
with 'ﺗﺎرﻳﺦ  ﺑﺪون 'selected. One tap changes it.
A name matches several tasks (for example two called اﻟﺘﻘﺮﻳﺮ :)the assistant asks
which one, with choices.
A reason is required but missing (postponed, waiting, stopped, partial): the assistant
asks once, with the owner's reason chips.
A numeric date such as 12/9/2026 is read as day/month/year (Egypt) and shown in
words ('12 2026 ﺳﺒﺘﻤﺒﺮ ,)'so he can catch a mistake.
2.7 Not understood. The assistant says what it heard ('ﺳﻤﻌﺖ )'... :and offers 'اﻟﺈﺿﺎﻓﺔ  اﻓﺘﺢ
ده  ﺑﺎﻟﻨﺺ ,'which opens quick add with the text already in the title. The sentence is saved to
a local list of unrecognized sentences (section 8) so patterns can be added later.
2.8 Limits (say so in the app help). It is not a free chat. It does not remember the
conversation and does not answer open questions such as 'ﻛﺘﻴﺮ؟  ﺻﺮﻓﺖ  ﻟﻴﻪ .'It handles one
command per sentence. It cannot delete anything.
3. Speech input and speech output
3.1 Recognition. Use the Android SpeechRecognizer through a maintained Flutter plugin
or a small platform channel. Locale ar-EG, falling back to ar. Partial results on. The
permission is RECORD_AUDIO, which the app already has.
اﻟﻤﺴﺎﻋﺪ اﻟﺼﻮﺗﻲ | Voice Assistant — Speciﬁcation v1.0
Page 3 of 13

<!-- PAGE 4 -->
3.2 Tap to start, tap to stop. The Android recognizer ends a session by itself after some
silence. The app must keep listening until the owner taps stop: chain sessions, merge the
results, avoid duplicated words and lost words at session boundaries, and stop at 60
seconds. Test this carefully on the owner's phone.
3.3 What depends on the phone. Accuracy for the Egyptian dialect, whether recognition
works in airplane mode, and whether audio is sent to Google services all depend on the
device and its speech packages. Do not assume. Run the test of section 10.3 and report it.
If recognition does not work offline, show a clear message with a shortcut to the system
speech settings, and do not hide it. The typed-sentence field always works.
3.4 Speech output. Use the Android text-to-speech engine with an Arabic voice. Settings:
on or off (default ON, as the owner chose), speed, and a tap to stop speaking. If no Arabic
voice is installed, fall back to text only and show a short guide to install one. Answers
about finance and health are spoken only if the owner turns on 'ﺻﻮﺗﻴﺎً  اﻟﺤﺴﺎﺳﺔ  اﻟﺮدود  ﻗﺮاءة'
(default OFF), because a spoken answer can be overheard. Speak at most 5 list items,
then say 'وﻛﻤﺎن N'. Do not speak amounts when amounts are masked (the eye icon of the
finance module).
3.5 Audio is not stored. The assistant never saves the recognized audio. The only
exception is the explicit commands 'ﺻﻮﺗﻴﺔ  ﻣﻼﺣﻈﺔ  ﺳﺠّﻞ 'and 'ﺻﻮﺗﻴﺔ  ﻓﻜﺮة  ﺳﺠّﻞ ,'which use
the existing voice-notes feature.
4. Understanding sentences (the rule-based parser)
4.1 Pipeline. Normalize the text, detect the command or question pattern, extract slots
(date, time, amount, quantity, category, reason, title), build an Intent with the missing
slots, then the ActionPlanner turns it into a Confirmation card or an Answer card. The
parser sits behind an IntentParser interface. This version has one implementation,
RuleBasedIntentParser. Patterns, synonyms and phrase variants live in data files (JSON
assets), so adding a variant does not need new code.
4.2 Normalization (matching only; never change what the owner sees). Remove
diacritics and punctuation, unify alef forms (ا →  آ  إ  أ ,)ه →  ة,  ي →  ى ,convert Arabic-Indic
digits to Western digits, convert Arabic number words to numbers, expand common
dialect variants from a dictionary (for example اﻧﻬﺎرده,  اﻟﻨﻬﺎردة,  اﻟﻨﻬﺎرده.)
4.3 Numbers in words. A pure Dart converter for Egyptian number words: ﺗﻼﺗﺔ،  اﺗﻨﻴﻦ،  واﺣﺪ،
ﻋﺸﺮﻳﻦ،  ﺧﻤﺴﺘﺎﺷﺮ،  أرﺑﻌﺘﺎﺷﺮ،  ﺗﻠﺘﺎﺷﺮ،  اﺗﻨﺎﺷﺮ،  ﺣﺪاﺷﺮ،  ﻋﺸﺮة،  ﺗﺴﻌﺔ،  ﺗﻤﺎﻧﻴﺔ،  ﺳﺒﻌﺔ،  ﺳﺘﺔ،  ﺧﻤﺴﺔ،  أرﺑﻌﺔ،
ﺗﻼف  ﺗﻼت  أﻟﻔﻴﻦ،  أﻟﻒ،  ﺗﻠﺘﻤﻴﺔ،  ﻣﻴﺘﻴﻦ،  ﻣﻴﺔ،  ﺧﻤﺴﻴﻦ،  أرﺑﻌﻴﻦ،  ﺗﻼﺗﻴﻦ،،  and combinations such as 'أﻟﻒ
وﺧﻤﺴﻤﻴﺔ 'and 'وﻧﺺ .'Money words: ج  ﺟﻨﻴﺔ،  ﺟﻨﻴﻪ،،  EGP, ﻗﺮش .Default currency EGP. Always
show the result as digits on the card.
اﻟﻤﺴﺎﻋﺪ اﻟﺼﻮﺗﻲ | Voice Assistant — Speciﬁcation v1.0
Page 4 of 13

<!-- PAGE 5 -->
4.4 Dates and times (one shared DateTimeResolver, pure Dart, unit-tested with a fixed
'now').
Day words: ﺑﻌﺪ  ﺑﻜﺮة،  ﺑﻌﺪ  ﺑﻜﺮة،  اﻣﺒﺎرح،  أول  اﻣﺒﺎرح،  اﻟﻨﻬﺎرده، N ,(2+ = ﻳﻮﻣﻴﻦ  ﺑﻌﺪ ) ﻳﻮﻣﻴﻦ /  ﻳﻮم /  أﻳﺎم
أﺳﺒﻮع  ﺑﻌﺪ.
Weekday names (اﻟﺠﻤﻌﺔ  اﻟﺨﻤﻴﺲ،  اﻟﺄرﺑﻊ،  اﻟﺘﻼت،  اﻻﺗﻨﻴﻦ،  اﻟﺄﺣﺪ،  اﻟﺴﺒﺖ، :)the next upcoming
date, today excluded. With 'اﻟﺠﺎي 'or 'اﻟﻘﺎدم 'it is still the next upcoming one. With 'اﻟﻠﻲ
ﻓﺎت 'or 'اﻟﻤﺎﺿﻲ 'it is the most recent past one.
Periods (used by questions): اﻟﺸﻬﺮ  ده،  اﻟﺸﻬﺮ  اﻟﺠﺎي،  اﻟﺄﺳﺒﻮع  ﻓﺎت،  اﻟﻠﻲ  اﻟﺄﺳﺒﻮع  ده،  اﻟﺄﺳﺒﻮع
دي  اﻟﺴﻨﺔ  ﻓﺎت،  اﻟﻠﻲ .The week starts on the day chosen in Settings (default Saturday).
Explicit dates: '2026 ﺳﺒﺘﻤﺒﺮ  12 ﻳﻮم', ' ﺳﺒﺘﻤﺒﺮ  12' ,'12/9/2026' ,'12/9 ﻳﻮم .'Numeric dates are
day/month/year. A missing year means the current year. Month names: ﻓﺒﺮاﻳﺮ،  ﻳﻨﺎﻳﺮ،
دﻳﺴﻤﺒﺮ  ﻧﻮﻓﻤﺒﺮ،  أﻛﺘﻮﺑﺮ،  ﺳﺒﺘﻤﺒﺮ،  أﻏﺴﻄﺲ،  ﻳﻮﻟﻴﻮ،  ﻳﻮﻧﻴﻮ،  ﻣﺎﻳﻮ،  أﺑﺮﻳﻞ،  ﻣﺎرس،.
A period word in a command (for example 'اﻟﺠﺎي  اﻟﺄﺳﺒﻮع )'does not define one date, so
the card asks with date chips.
A date in the past in a command shows a visible 'ﻓﺎت  اﻟﺘﺎرﻳﺦ 'chip.
Times: '8' ,' اﻟﺼﺒﺢ  9' ,' اﻟﻌﺼﺮ  5' ,' ﺗﻠﺖ  إﻻ', ' رﺑﻊ  إﻻ', ' ورﺑﻊ', ' وﻧﺺ  ﺧﻤﺴﺔ  اﻟﺴﺎﻋﺔ', ' 5:30' ,'5 اﻟﺴﺎﻋﺔ
اﻟﻀﻬﺮ', ' ﺑﺎﻟﻠﻴﻞ .'Markers: ﺻﺒﺎﺣﺎً /  اﻟﺼﺒﺢ = AM; ﺑﺎﻟﻠﻴﻞ /  ﻣﺴﺎءً /  اﻟﻀﻬﺮ  ﺑﻌﺪ /  اﻟﻌﺼﺮ;  12:00 = اﻟﻀﻬﺮ= 
PM. With no marker: 1 to 6 = PM, 7 to 11 = AM, 12 = noon. The card shows AM or PM
clearly and the owner can edit.
'ﺑﺴﺎﻋﺔ  ﻗﺒﻠﻬﺎ 'or 'ﺳﺎﻋﺔ  ﺑﻨﺺ  ﻗﺒﻠﻬﺎ 'sets the reminder offset.
Expected results with the fixed now = Saturday 7 Nov 2026 10:00 (device time zone
Africa/Cairo, week starts Saturday):
→ ﻳﻮﻣﻴﻦ  ﺑﻌﺪ;  09-11-2026 → ﺑﻜﺮة  ﺑﻌﺪ(;  Sunday) 08-11-2026 → ﺑﻜﺮة;  07-11-2026 → اﻟﻨﻬﺎرده
.10-11-2026 → أﻳﺎم  3 ﺑﻌﺪ;  09-11-2026
.05-11-2026 → اﻣﺒﺎرح  أول;  06-11-2026 → اﻣﺒﺎرح
(.today excluded) 14-11-2026 → اﻟﺴﺒﺖ;  12-11-2026 → اﻟﺨﻤﻴﺲ
(.day/month) 12-09-2026 → 12/9 ﻳﻮم
.to 2026-11-06 31-10-2026 → ﻓﺎت  اﻟﻠﻲ  اﻟﺄﺳﺒﻮع;  to 2026-11-13 07-11-2026 → ده  اﻟﺄﺳﺒﻮع
.to 2026-10-31 01-10-2026 → ﻓﺎت  اﻟﻠﻲ  اﻟﺸﻬﺮ;  to 2026-11-30 01-11-2026 → ده  اﻟﺸﻬﺮ
5. Commands (what the owner can say)
5.1 Rules for all commands.
One command per sentence. A command word is optional when the sentence has a
date and an intent verb. For example the owner's own style 'ﻣﻮﻧﺘﺎج  اﻋﻤﻞ  ﻋﺎﻳﺰ  ﺑﻜﺮة  اﻧﺎ
اﻻﻋﻼن 'must create a task.
اﻟﻤﺴﺎﻋﺪ اﻟﺼﻮﺗﻲ | Voice Assistant — Speciﬁcation v1.0
Page 5 of 13

<!-- PAGE 6 -->
The title is the rest of the sentence after removing the command word, the date
phrase, the time phrase and filler words (اﻧﻲ  ﻻزم،  ﻫـ،  ﻋﺎﻳﺰ،  اﻧﺎ، .)The title keeps the
original spelling from the transcript, not the normalized spelling. If the title is empty,
the assistant asks 'إﻳﻪ؟  ﺗﺴﺠﻞ.'
Cards use the app's existing defaults (default reminder type and offsets from the
Settings of Round 1).
5.2 Commands. Every command ends in a Confirmation card and then runs through the
existing service named in the last column.
Intent Examples (spoken) Card and action
create_task / '5 اﻟﺴﺎﻋﺔ  اﻟﻌﻤﻴﻞ  أﻛﻠﻢ  ﺑﻜﺮة  ﺳﺠّﻞ' 
' /اﻻﻋﻼن  ﻣﻮﻧﺘﺎج  اﻋﻤﻞ  ﻋﺎﻳﺰ  ﺑﻜﺮة  اﻧﺎ' 
ﺿﻴﻒ' / ' اﻟﺪﻛﺘﻮر  ﻫﻘﺎﺑﻞ  اﻟﺨﻤﻴﺲ  ﻳﻮم' 
'اﻟﻔﺎﺗﻮرة  اراﺟﻊ  ﻣﻬﻤﺔ
Task with title, date, time,
reminder from defaults. Same
code as quick add.
create_errand / ' اﻟﺒﻨﺰﻳﻦ  اﺟﻴﺐ  ﺑﻜﺮة  ﻣﺸﻮار  ﺳﺠّﻞ' 
'12 اﻟﺴﺎﻋﺔ  اﻟﺒﻨﻚ  اﻟﻨﻬﺎرده  ﻣﺸﻮار' 
Errand. The word ﻣﺸﻮار is
required. Location is the text
after ﻣﻦ or ﻋﻨﺪ ,if spoken.
create_reminder / ' اﺣﻤﺪ  اﻛﻠﻢ  9 اﻟﺴﺎﻋﺔ  ﺑﻜﺮة  ﻓﻜﺮﻧﻲ' 
'اﻟﻔﺎﺗﻮرة  ادﻓﻊ  ﻳﻮﻣﻴﻦ  ﺑﻌﺪ  ﻧﺒﻬﻨﻲ' 
Task with a reminder at the
spoken time (default type from
Settings).
update_status اﺑﺘﺪﻳﺖ' / ' اﻟﺘﻘﺮﻳﺮ  ﻣﻬﻤﺔ  ﺧﻠﺼﺖ' 
ﻟﺒﻜﺮة  اﻟﺘﻘﺮﻳﺮ  ﻣﻬﻤﺔ  اﺟّﻞ' / ' اﻟﻤﻮﻧﺘﺎج
اﻟﻌﻤﻴﻞ  ﻣﻬﻤﺔ' / ' ﻓﻠﻮس  ﻣﻔﻴﺶ  ﻻن
ﻣﻬﻤﺔ  وﻗﻔﺖ' / ' اﻟﺪﻛﺘﻮر  رد  ﻣﺴﺘﻨﻴﺔ
ﻧﺺ  ﻋﻤﻠﺖ' / ' اﻟﻤﻴﺰاﻧﻴﺔ  ﺑﺴﺒﺐ  اﻻﻋﻼن
'ﺗﻌﺒﺖ  ﻻﻧﻲ  اﻟﺘﺼﻤﻴﻢ  ﻣﻬﻤﺔ
Status values: done, in progress,
postponed (date and reason),
waiting (reason), stopped
(reason), partial (progress and
reason). Same status service,
rules and events as the status
sheet.
log_expense ﺻﺮﻓﺖ' / ' ﺟﻨﻴﻪ  ﺑﻌﺸﺮة  ﺷﺎي  ﺳﺠّﻞ' 
ﻓﺎﺗﻮرة  300 دﻓﻌﺖ' / ' ﺑﺮه  اﻛﻞ  ﻋﻠﻰ  50
' اﻣﺒﺎرح  اﻟﻨﺖ
Expense with category, amount,
essential or side, date. Finance
service.
log_income ﻗﺒﻀﺖ' / ' ﻋﻤﻴﻞ  ﻣﻦ  5000 دﺧﻞ' 
'ﻣﺮﺗﺐ  8000
Income.
log_habit / ' ﻗﻬﻮة  ﻛﻮﺑﺎﻳﺘﻴﻦ' / ' ﻗﻬﻮة  ﺷﺮﺑﺖ' 
ﺻﻔﺤﺎت  5 ﻗﺮﻳﺖ' / ' اﻟﻔﺠﺮ  ﺻﻠﻴﺖ' 
'اﻟﺼﺒﺎح  اذﻛﺎر  ﻋﻤﻠﺖ' / ' ﻗﺮان
Habit log: +1, a quantity, or a
checklist tick. Habits service.
create_note / ' اﻟﺼﺒﺮ  ﺑﻴﺘﻌﻠﻢ  ﺑﻴﺬاﻛﺮ  اﻟﻠﻲ  ﻣﻼﺣﻈﺔ' 
 ...'ﻣﻼﺣﻈﺔ  ﺳﺠّﻞ' 
Note. The words ﺣﻜﻤﺔ or اﻗﺘﺒﺎس
make its kind quote.
اﻟﻤﺴﺎﻋﺪ اﻟﺼﻮﺗﻲ | Voice Assistant — Speciﬁcation v1.0
Page 6 of 13

<!-- PAGE 7 -->
A command for a module that does not exist yet, or that is turned off, answers with a clear
message and does nothing.
5.3 Matching rules.
Task lookup (update_status): compare normalized title tokens and compute a score.
Prefer tasks due today, then overdue, then other open ones. Two or more tasks within
10 percent of the best score: show choices. No match: say 'اﺳﻤﻬﺎ  ﻣﻬﻤﺔ  ﻣﺎﻟﻘﻴﺘﺶ '... and
offer to create it.
Expense category: 1) the labels of the quick favorites, 2) category names, 3) the
synonyms file (ﺗﻠﻴﻔﻮن،  ﻧﺖ،  ﻓﺎﺗﻮرة،  ﻣﻮاﺻﻼت،  ﺑﻨﺰﻳﻦ،  ﺑﻘﺎﻟﺔ،  ﻣﻄﻌﻢ،  ﺑﺮه،  اﻛﻞ  ﻛﺎﻓﻴﻪ،  ﻗﻬﻮة،  ﺷﺎي،
ﻋﻼج  دوا، ,)... 4) otherwise 'أﺧﺮى 'with category chips on the card.
Habit: by name, built-in key and synonyms. 'ﻛﻮﺑﺎﻳﺔ 'alone is ambiguous between coffee
and water, so ask with chips.
Reason: by the owner's reasons list and synonyms (اﻟﻤﻴﺰاﻧﻴﺔ  ﻓﻠﻮس،  ﻣﻌﻴﻴﺶ  ﻓﻠﻮس،  ﻣﻔﻴﺶ.)
Unknown text becomes a custom reason.
Never guess silently. Ask, or show the chip.
6. Questions (what the owner can ask)
Each answer is built by the same services as the dashboards, so numbers always match
the screens.
Intent Examples (spoken) Card and action
create_idea ﻓﻜﺮة  ﺳﺠّﻞ' / ' ﻟﻠﻤﺸﺎوﻳﺮ  ﺗﻄﺒﻴﻖ  ﻓﻜﺮة' 
...'
Idea.
record_voice_note ﻣﻼﺣﻈﺔ  ﺳﺠّﻞ' / ' ﺻﻮﺗﻴﺔ  ﻓﻜﺮة  ﺳﺠّﻞ' 
'ﺻﻮﺗﻴﺔ 
Opens the recorder and saves a
voice-only idea or note (existing
voice-notes feature). No
transcription.
create_wishlist_item ﺑﺄﻟﻒ  ﺳﻤﺎﻋﺔ  ﻟﻠﻤﺸﺘﺮﻳﺎت  ﺿﻴﻒ' 
'ﻛﺎﻣﻴﺮا  اﺷﺘﺮي  ﻋﺎﻳﺰ' / ' وﺧﻤﺴﻤﻴﺔ
Wishlist item with an optional
price.
create_health_item ' اﻟﺨﻤﻴﺲ  اﻟﺄﺳﻨﺎن  ﻛﺸﻒ  اروح  ﻓﻜﺮﻧﻲ' 
'ﺳﻜﺮ  ﺗﺤﻠﻴﻞ  اﻋﻤﻞ  ﻣﺤﺘﺎج/ ' 
Health item with status needed
and an optional date.
اﻟﻤﺴﺎﻋﺪ اﻟﺼﻮﺗﻲ | Voice Assistant — Speciﬁcation v1.0
Page 7 of 13

<!-- PAGE 8 -->
Rules:
When a question is about a date, the answer starts with the date in words ('12 ﻳﻮم
2026 ﺳﺒﺘﻤﺒﺮ.)'
A question about a module that does not exist yet or is off gets a clear message.
Before the timeline of Round 7 exists, the recap of a single day shows only what each
module can answer (tasks, expenses, habits, notes).
Spoken text comes from a separate SpeechComposer with Arabic templates and a
plural helper: ﻣﻬﻤﺔ  ﻓﺄﻛﺜﺮ  ١١ ﻣﻬﺎم،  ٠١ إﻟﻰ  ٣ ﻣﻬﻤﺘﻴﻦ،  ٢ ﻣﻬﻤﺔ،  ١ .The helper is unit-tested.
Intent Examples (spoken) Answer card
agenda ﺑﻌﺪ  اﻳﻪ  وراﻳﺎ' / ' اﻟﻨﻬﺎرده؟  اﻳﻪ  وراﻳﺎ' 
' /اﻟﺨﻤﻴﺲ؟  ﻳﻮم  اﻳﻪ  ﻋﻨﺪي' / ' ﻳﻮﻣﻴﻦ؟
'ده؟  اﻻﺳﺒﻮع  اﻳﻪ  وراﻳﺎ' 
Tasks and errands in time order,
overdue count, obligations due,
health appointments, and (for today
only) habits not done yet.
recap ﻓﺎت  اﻟﻠﻲ  اﻻﺳﺒﻮع' / ' اﻣﺒﺎرح؟  اﻳﻪ  ﻋﻤﻠﺖ' 
' /؟ 12/9 ﻳﻮم  ﺣﺼﻞ  اﻟﻠﻲ  اﻳﻪ' / ' اﻳﻪ؟  ﻋﻤﻠﺖ
'ده  اﻟﺸﻬﺮ  ﻣﻠﺨﺺ' 
Done count, postponed count with
the top reason, habit completion,
spending total, notes and ideas
counts, highlights, and a button to
open the day or period in the
timeline.
spending / ' ده؟  اﻟﺸﻬﺮ  ﺑﺮه  اﻛﻞ  ﻋﻠﻰ  ﻛﺎم  ﺻﺮﻓﺖ' 
ﻣﺼﺮوف' / ' ﻋﻠﻴﻬﺎ؟  ﺑﺼﺮف  ﺣﺎﺟﺔ  اﻛﺘﺮ' 
'ﻛﺎم؟  اﻟﻨﻬﺎرده
Totals, top categories, essential vs
side, comparison with the previous
period.
habit_status اﻳﻪ  ﺻﻠﻴﺖ' / ' اﻟﻨﻬﺎرده؟  ﻗﻬﻮة  ﻛﺎم  ﺷﺮﺑﺖ' 
اﻻﺳﺒﻮع  ﺑﺎﻟﻘﺮان  اﻟﺘﺰاﻣﻲ' / ' اﻟﻨﻬﺎرده؟
'ده؟ 
Progress and streak.
pending اﻳﻪ' / ' اﻟﻤﺆﺟﻞ؟  اﻳﻪ' / ' ﻋﻨﺪي؟  اﻟﻤﺘﺄﺧﺮ  اﻳﻪ' 
'ﻣﺴﺘﻨﻲ؟  اﻟﻠﻲ
Lists by status with their reasons.
obligations اﻻﻟﺘﺰاﻣﺎت  اﻳﻪ' / ' ده؟  اﻟﺸﻬﺮ  اﻳﻪ  ﻋﻠﻴﺎ' 
'اﻟﻤﺘﺄﺧﺮة؟ 
Late and upcoming obligations.
health_pending ' اﻟﻤﺆﺟﻠﺔ؟  اﻟﻜﺸﻮﻓﺎت  اﻳﻪ' Needed and postponed items and
how long each has waited.
wishlist ' ﻛﺎم؟  ﻋﺎﻳﺰﻫﺎ  اﻟﻠﻲ  اﻟﻤﺸﺘﺮﻳﺎت  اﺟﻤﺎﻟﻲ' Wishlist totals.
اﻟﻤﺴﺎﻋﺪ اﻟﺼﻮﺗﻲ | Voice Assistant — Speciﬁcation v1.0
Page 8 of 13

<!-- PAGE 9 -->
7. Execution, safety and privacy
Flow: parser → Intent → ActionPlanner → Confirmation card → owner confirms → the
existing service executes → Undo snackbar.
Not available by voice: deleting anything, permanent delete, emptying the trash,
backup and restore, export, changing settings, changing the lock. The assistant
answers 'ﺑﺎﻟﺼﻮت  ﻣﺘﺎح  ﻣﺶ  ده.'
Voice confirmation applies to the latest card only, within the window, with the word
lists of 2.4. Other speech is ignored. After the window, the card stays and waits for
taps.
When the app lock is on, the assistant works only after unlocking, and its content is
hidden in the recent-apps screen.
All understanding runs on the phone. The app sends nothing anywhere, has no
INTERNET permission, and CI checks that the merged release manifest does not
contain it.
The in-app help explains that speech recognition is done by Android and may use
Google speech services depending on the phone.
The list of unrecognized sentences is text only and stays on the phone.
8. Settings and local data
Settings > اﻟﺼﻮﺗﻲ  اﻟﻤﺴﺎﻋﺪ:
Spoken replies (ON by default), speech speed, speak sensitive answers (OFF).
Voice confirmation (ON), confirmation window in seconds (5).
Recognition language: Arabic ar-EG by default (English later).
Keep the list of unrecognized sentences (ON), with 'ﻋﺮض / View' and 'ﻣﺴﺢ / Clear'.
'اﻟﻤﻴﻜﺮوﻓﻮن  اﺧﺘﺒﺎر 'wizard: records one sentence, shows the transcript, and says
whether the phone looks offline (using the existing network-state permission).
'اﻟﺼﻮت  اﺧﺘﺒﺎر :'speaks a sample.
A help page with example sentences for every command and question.
Data: one new table unrecognized_phrases (id, text, at, handled, plus the common
columns), a few settings keys, and JSON assets for patterns and synonyms (categories,
habits, statuses, reasons, month and weekday names). No audio is stored. Later option,
not now: owner-defined aliases for habits and categories.
اﻟﻤﺴﺎﻋﺪ اﻟﺼﻮﺗﻲ | Voice Assistant — Speciﬁcation v1.0
Page 9 of 13

<!-- PAGE 10 -->
9. Code structure
lib/features/assistant/ with: assistant_sheet, assistant_controller (state machine: idle,
listening, processing, card, speaking), speech_input_service, tts_service, text_normalizer,
number_words_ar, date_time_resolver, intent_parser (interface),
rule_based_intent_parser, patterns and synonyms assets, action_planner,
confirmation_card, answer_composer, speech_composer, plural_ar, unrecognized_log.
Tests in test/unit/assistant/. Business logic stays in the existing services.
10. Tests
10.1 Phrase corpus. A committed file test/assistant_corpus_ar.json with at least 150
entries: phrase, the fixed now, expected intent and expected slots. It includes every
example of this file and, later, the owner's own real sentences. The build fails if the
committed corpus does not pass 100 percent.
10.2 Unit tests. Normalizer; number words (including 'وﺧﻤﺴﻤﻴﺔ  أﻟﻒ 'and 'وﻧﺺ;)'
DateTimeResolver with every expected result of 4.4 and these times: ',17:00 → '5 اﻟﺴﺎﻋﺔ
18:15 → ' ورﺑﻊ  ﺳﺘﺔ, ' 12:00 → ' اﻟﻀﻬﺮ, ' 17:00 → ' اﻟﻌﺼﺮ  5' ,20:00 → ' ﺑﺎﻟﻠﻴﻞ  8' ,09:00 → '9 اﻟﺴﺎﻋﺔ'  ;the
Arabic plural helper; the confirmation keyword matcher; task, category, habit and reason
matching; the ActionPlanner; the CI manifest check.
10.3 Speech recognition test on the owner's phone. The agent prepares a script and a
report template. The owner reads 30 sentences: 10 commands with amounts, 10 with
dates and times, 5 questions, and 5 with Egyptian dialect words. Run it online and in
airplane mode. For each sentence record the transcript, whether numbers and dates were
right, and whether the intent was recognized. Write the results and the conclusions in
DECISIONS.md. The owner decides whether to continue to step 6.
10.4 UI tests with a fake speech source that injects transcripts, for every card type and
for voice confirmation.
10.5 Speech output test. Check whether an Arabic voice exists on the phone, speak the
five answer types, and report the quality.
11. Acceptance tests (the owner, on his phone)
1. The assistant opens from the Today microphone button, from More, and from the app
shortcut.
2. Say '5 اﻟﺴﺎﻋﺔ  اﻟﻌﻤﻴﻞ  أﻛﻠﻢ  ﺑﻜﺮة  ﺳﺠّﻞ .'The card shows a task titled 'اﻟﻌﻤﻴﻞ  أﻛﻠﻢ ,'tomorrow's
date in words, 5:00 م ,and the default reminder. Confirm by tap: it appears tomorrow
in Today with its reminder. Undo works.
3. Say 'اﻻﻋﻼن  ﻣﻮﻧﺘﺎج  اﻋﻤﻞ  ﻋﺎﻳﺰ  ﺑﻜﺮة  اﻧﺎ( 'no command word). A task card appears.
اﻟﻤﺴﺎﻋﺪ اﻟﺼﻮﺗﻲ | Voice Assistant — Speciﬁcation v1.0
Page 10 of 13

<!-- PAGE 11 -->
4. Say 'ﺟﻨﻴﻪ  ﺑﻌﺸﺮة  ﺷﺎي  ﺳﺠّﻞ .'The card shows the expense, category 10 , وﻗﻬﻮة  ﺷﺎي EGP,
side. Confirm by saying 'ﺗﻤﺎم .'It is saved and appears in Finance.
5. Say 'ﻗﻬﻮة  ﻛﻮﺑﺎﻳﺘﻴﻦ :'the coffee habit gets +2. Say 'اﻟﻔﺠﺮ  ﺻﻠﻴﺖ :'the Fajr item is ticked.
6. Say 'ﻓﻠﻮس  ﻣﻔﻴﺶ  ﻻن  ﻟﺒﻜﺮة  اﻟﺘﻘﺮﻳﺮ  ﻣﻬﻤﺔ  اﺟّﻞ .'The card shows postponed, tomorrow's date
and the reason 'ﻓﻠﻮس  ﻣﻔﻴﺶ .'With two tasks called اﻟﺘﻘﺮﻳﺮ ,the assistant asks which
one.
7. Say 'ﺻﻮﺗﻴﺔ  ﻓﻜﺮة  ﺳﺠّﻞ .'The recorder opens, a voice-only idea is saved, and it plays back.
8. Ask 'اﻟﻨﻬﺎرده؟  اﻳﻪ  وراﻳﺎ .'An answer card appears and is spoken, and it matches the Today
screen. Ask 'ﻳﻮﻣﻴﻦ؟  ﺑﻌﺪ  اﻳﻪ  وراﻳﺎ :'it matches the tasks of that date.
9. Ask 'اﻳﻪ؟  ﻋﻤﻠﺖ  ﻓﺎت  اﻟﻠﻲ  اﻻﺳﺒﻮع .'The numbers equal the Stats screen for that week.
10. Ask '؟12/9 ﻳﻮم  ﺣﺼﻞ  اﻟﻠﻲ  اﻳﻪ .'The assistant first says the date in words ('12 2026 ﺳﺒﺘﻤﺒﺮ,)'
then shows that day.
11. Say a sentence the assistant cannot parse. It answers 'ﺳﻤﻌﺖ  ﻣﻔﻬﻤﺘﺶ، .'... :The button
'ده  ﺑﺎﻟﻨﺺ  اﻻﺿﺎﻓﺔ  اﻓﺘﺢ 'opens quick add with the text in the title, and the sentence
appears in the unrecognized list.
12. Say 'اﻟﺘﻘﺮﻳﺮ  ﻣﻬﻤﺔ  اﻣﺴﺢ .'The answer is 'ﺑﺎﻟﺼﻮت  ﻣﺘﺎح  ﻣﺶ  ده.'
13. Finance and health answers are text only by default. Turning on 'اﻟﺤﺴﺎﺳﺔ  اﻟﺮدود  ﻗﺮاءة
ﺻﻮﺗﻴﺎً 'makes them spoken. Masked amounts are never spoken.
14. Airplane mode: the result is written in the report of 10.3. The typed-sentence field
works in any case. The CI manifest check shows no INTERNET permission.
15. A 20-second sentence with pauses, using tap to start and tap to stop, is captured
completely, with no lost words at session boundaries.
16. With the app lock on, the assistant needs the unlock and the recent-apps screen
hides it.
17. The new APK installs over the previous one with the data intact.
12. Build steps
Prerequisites: Rounds 0 to 6 of CHANGES.md are done, so the modules exist. Round 7
(timeline) is recommended before this work, because the question 'ﻳﻮم  ﺣﺼﻞ  اﻟﻠﻲ  اﻳﻪ'... 
uses it. If this work starts earlier, that question answers with the limited recap of section
6.
Step 1 — Foundations, no UI: text normalizer, Arabic number words,
DateTimeResolver, plural helper, with the tests of 10.2.
Step 2 — Parser: RuleBasedIntentParser. First the commands create_task,
create_errand, create_reminder, log_expense, log_habit, create_note, create_idea.
Then update_status, log_income, wishlist, health, record_voice_note. Then the
questions. The corpus test of 10.1.
اﻟﻤﺴﺎﻋﺪ اﻟﺼﻮﺗﻲ | Voice Assistant — Speciﬁcation v1.0
Page 11 of 13

<!-- PAGE 12 -->
Step 3 — Cards and execution, typed input only: ActionPlanner, Confirmation cards,
execution through the existing services, Undo, and the assistant sheet with the typed
field only (no voice yet). The owner tests by typing the example sentences.
Step 4 — Answers: Answer cards and the SpeechComposer (text only) for all
questions, matching the dashboards.
Step 5 — Voice input: tap to start and tap to stop with chained sessions, and the
speech recognition report of 10.3. STOP here and report. The owner decides whether
to continue.
Step 6 — Voice output and settings: text-to-speech replies, voice confirmation, the
assistant settings, the sensitive-answers rule, and the microphone and voice test
wizards.
Step 7 — Entry points and polish: the microphone button, the More item, the app
shortcut, the voice-note and voice-idea commands, the unrecognized list, the help
page, and the documents.
Optional later, only if the owner asks: English commands, owner-defined aliases,
navigation commands ('اﻟﻤﺼﺮوﻓﺎت  اﻓﺘﺢ ,)'and a smarter parser plugged in behind the
IntentParser interface.
After each step: tests, README, CHANGELOG and DECISIONS, commit, tag, CI APK, a
plain-Arabic test checklist, and wait for approval.
13. Risks and open items
Recognition of the Egyptian dialect, especially numbers and dates, is unknown until
the test of 10.3. The cards show everything in words so mistakes are caught before
saving.
The Android recognizer may stop after silence. The chained sessions of 3.2 must be
tested. If they prove unreliable, propose alternatives (for example an on-device
speech model, which is heavy) and ask the owner before building them.
Offline recognition depends on the phone's speech packages. Never claim offline
support unless it was tested.
An Arabic voice for speech output may need to be installed on some Xiaomi phones.
Rule-based coverage is limited. The unrecognized list and the owner's real sentences
extend it. Expect several rounds of additions.
One command per sentence: compound sentences are not split.
Open items for the owner: send 10 sentences he really says (commands and
questions), confirm the default reminder type for voice-created tasks, and confirm
the name of the app shortcut.
اﻟﻤﺴﺎﻋﺪ اﻟﺼﻮﺗﻲ | Voice Assistant — Speciﬁcation v1.0
Page 12 of 13

<!-- PAGE 13 -->
14. Kickoff messages (the owner pastes one per step)
Start with step 1. Before step 5 starts, wait for the owner's go-ahead.
. اﻟﺨﻄﻮة  أﻗﺴﺎم  ﻣﻊ  7و  0 اﻟﻘﺴﻤﻴﻦ  اﻗﺮأ(.  12 اﻟﻘﺴﻢ ) ﻓﻘﻂ  N اﻟﺨﻄﻮة  ﻧﻔّﺬ.  ﻓﻘﻂ  VOICE.md ﻣﻦ  اﺑﺪأ
ﻣﺶ  ﺣﺎﺟﺔ  وأي  ﺗﺎﻧﻴﺔ،  ﺧﻄﻮة  ﺗﺒﺪأش  ﻣﺎ.  ﻧﻔّﺬ  وﺑﻌﺪﻫﺎ  ﻣﻮاﻓﻘﺘﻲ،  واﻧﺘﻈﺮ  ﺑﺎﻟﻌﺮﺑﻲ  ﻗﺼﻴﺮة  ﺧﻄﺔ  اﻋﻤﻞ
،DECISIONSو  CHANGELOGو  README ﺣﺪّث  اﻻﺧﺘﺒﺎرات،  ﺷﻐّﻞ:  اﻟﺂﺧﺮ  ﻓﻲ.  ﻓﻴﻬﺎ  اﺳﺄﻟﻨﻲ  واﺿﺤﺔ
ﻋﻠﻰ  اﻟﺘﺠﺮﺑﺔ  ﺧﻄﻮات  وادّﻳﻨﻲ  ،APK ﻟﻠـ  رﺳﻤﻲ  Releaseو  voice-N ﺑﺎﺳﻢ  tagو  commit اﻋﻤﻞ
.ﻣﻮﺑﺎﻳﻠﻲ 
اﻟﻤﺴﺎﻋﺪ اﻟﺼﻮﺗﻲ | Voice Assistant — Speciﬁcation v1.0
Page 13 of 13