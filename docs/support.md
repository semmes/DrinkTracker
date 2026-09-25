{% assign state = site.platform_state | default: 1 %}
# Support

Tallyist records the drinks you log and shows them back to you as a calendar,
totals, and charts. It does not set goals, give advice, or say what is too much.
It needs no account and has no servers.

<div class="support-contact">
<a class="support-contact__button" href="mailto:tallyist@gmail.com">Email support</a>
<p class="support-contact__address">tallyist@gmail.com</p>
</div>

Bug reports are most useful with what you did, what you expected, what happened
instead, and your iPhone model and iOS version. For the watch app, add your
watch model and watchOS version.

## Questions

<details>
<summary>Do I need an account?</summary>
{% if state >= 3 -%}
<p>No account is required on either platform. On iPhone there is nothing to sign in to. On Android, Tallyist asks for no sign-in, and has no permission to use the internet.</p>
{%- else -%}
<p>No. On iPhone there is nothing to sign in to.</p>
{%- endif %}
</details>

<details>
<summary>Where is my data?</summary>
<p>On your devices, in your own private iCloud if iCloud is on for Tallyist, and in Apple Health if you let Tallyist save to it. Tallyist has no servers and cannot see your log.{% if state >= 3 %} On Android, your log is stored on the device, and in your own Android backup if you use one. That backup belongs to your Google account. The developer never receives it and cannot read it.{% endif %}</p>
</details>

<details>
<summary>Does Tallyist give advice?</summary>
<p>No. It reports what you logged. There are no goals, limits, scores, or guidelines. The optional references are published US surveys, each named and dated in the app, and they describe a population rather than setting a target.</p>
</details>

<details>
<summary>What does the tip jar unlock?</summary>
<p>Nothing. Every feature is free. The tip jar, in Settings under Buy me a drink, is there for anyone who wants to say thanks. Apple handles the payment; Tallyist never sees your payment details.</p>
</details>

<details>
<summary>Can I use it without Apple Health?</summary>
<p>Yes. Apple Health is optional. Logging, the calendar, Trends, History, and export all work without it.</p>
</details>

<details>
<summary>How do I change the standard drink size?</summary>
<p>In Settings, under Standard drink size: United States (14 g of alcohol), United Kingdom (8 g), or Australia (10 g). Totals are shown in the unit you pick, and changing it recounts past days too. It never changes what you logged, only how it is counted.</p>
</details>

<details>
<summary>Can I add a drink to an earlier day?</summary>
<p>Yes. Add, change, or remove a drink on any past day from History or the Calendar. On the Calendar, press and drag across days to fill a stretch at once.</p>
</details>

<details>
<summary>Can I get my log out?</summary>
<p>Yes. Settings → Export log turns your whole record into a CSV file, created on your device and sent only where you send it.</p>
</details>

<details>
<summary>How do I delete my data?</summary>
<p>Any entry you logged can be deleted in the app. A drink or a no-alcohol day that another app recorded in Apple Health is deleted in that app or in the Health app, and Tallyist follows. Deleting the app removes everything stored on the device.{% if state >= 2 %} On Apple Watch, deleting the watch app removes the watch's copy.{% endif %} iCloud copies can be removed in the iOS Settings app under your Apple Account → iCloud → Manage Account Storage. Drinks saved to Apple Health can be deleted there, under Browse → Other Data → Alcohol Consumption.</p>
</details>

<details>
<summary>Is there an Apple Watch app?</summary>
{% if state >= 2 -%}
<p>Yes. It installs with the iPhone app. watchOS 26 and later.</p>
{%- else -%}
<p>It is coming soon. It will require the iPhone app and watchOS 26 or later.</p>
{%- endif %}
</details>

<details>
<summary>Is there an Android app?</summary>
{% if state >= 3 -%}
<p>Yes, on Google Play. Same app, same rules.</p>
{%- else -%}
<p>Not yet. It is coming soon, with the same rules.</p>
{%- endif %}
</details>

<details>
<summary>How do I log a drink?</summary>
<p>Tap the plus on the Today screen: one tap, one drink. By default that records one standard drink with no type. You can add the type, size, and strength afterwards, or leave them out and it still counts. Once you describe a drink, the next taps that day record another of it, and each day starts back at a standard drink. If you'd rather the plus always repeated the drink you log most, choose that under Settings → What the counter logs. Add specific, beside Logged today, opens the type, size, and strength controls when you want them. The Home Screen widget logs one drink without opening the app, the same way.</p>
</details>

<details>
<summary>How do I fix a mistake?</summary>
<p>Tap the minus on Today to remove the most recent drink. There are 10 seconds to undo it. Any entry can be edited or removed later from History or the Calendar: tap a day, then tap the entry.</p>
</details>

<details>
<summary>How do I record a day without a drink?</summary>
<p>On Today, with the counter at zero, tap Record no alcohol today. For past days, tap the day in the Calendar. "No entries" and "no alcohol" are different facts, and Tallyist records the second only when you say so, or when another app writes a zero to Apple Health.</p>
</details>

<details>
<summary>What does press and drag on the Calendar do?</summary>
<p>Touch and hold a day, then drag across a stretch of days to give them all the same answer at once: record them as no alcohol in one tap, or log the same number of drinks on each. Days that already have a record are never touched.</p>
</details>

<details>
<summary>Why don't my drinks appear in Apple Health?</summary>
<p>Saving to Health is optional and off until you allow it. Check the Health app → Sharing → Apps → Tallyist, and Tallyist's own Settings, which shows the current Health status in plain words.</p>
</details>

<details>
<summary>I used another app before. Does my old data show up?</summary>
<p>Yes. With Health access allowed, drinks that other apps recorded in Apple Health appear in Tallyist automatically, labeled From Apple Health and counted as logged, each recorded beverage as one drink. A day the other app recorded there as zero drinks appears as a no-alcohol day, labeled the same way; a day it recorded nothing for stays blank. Health doesn't store their size or strength. For a single-drink entry, tap it and choose Add details to record the type, size, and strength in Tallyist; the Health record stays exactly as the other app wrote it. Entries that count more than one drink stay as they are. To change or delete what Health holds, do it in the app that logged it, or in the Health app, and Tallyist follows. That includes a no-alcohol day that came from Health: it has no remove control in Tallyist, and logging a drink on that day replaces it.</p>
</details>

<details>
<summary>Does my log sync between my devices?</summary>
<p>Yes, through your own private iCloud, if the device is signed in to iCloud. Tallyist's Settings shows the sync state. There is no account with the developer, and the developer cannot read your log.</p>
</details>

<details>
<summary>What do the calendar colours mean?</summary>
<p>One blue, light to dark: more drinks, darker cell. A day recorded as no alcohol gets an outline instead of a fill, and a blank day means no record at all. The legend under the calendar names the ranges.</p>
</details>

<details>
<summary>How do I cancel a recurring tip?</summary>
<p>Any time, in Tallyist under Settings → Buy me a drink → Manage or cancel, or in the iOS Settings app under your Apple Account → Subscriptions. Tallyist reminds you a week before each renewal so you can cancel before being charged.</p>
</details>

<details>
<summary>How does the watch app work?</summary>
<p>{% if state < 2 %}From version 1.4, the {% else %}The {% endif %}watch app logs a drink when you tap the plus. Hold the plus to say what it was, tap the minus to remove today's newest drink, or record a day as no alcohol. Today's count can go on your watch face or in the Smart Stack, and the Smart Stack card has its own plus. The watch keeps its own copy of your log and syncs with your iPhone through your private iCloud. The watch app doesn't use Apple Health itself: drinks you log on the watch are saved to Health by your iPhone once they have synced, if you allow it, and a drink Health already holds can only be removed on the iPhone.</p>
</details>

<details>
<summary>What is Apple Health on Trends?</summary>
<p>{% if state < 2 %}From version 1.4, {% endif %}Trends can show four figures from Apple Health beside your log: resting heart rate, sleep, heart rate variability, and wrist temperature, each as your own average on nights you logged drinks and on nights you recorded as no alcohol. They are off until you turn them on in Settings → Apple Health on Trends, or from a card on Trends that asks once. An Apple Watch records them, so without one Health may have none and Trends shows nothing. Tallyist reads them on your device when Trends shows them and never stores them. Turn a switch off any time, or remove access in the Health app under Sharing → Apps → Tallyist.</p>
</details>

## Documents

- [Privacy Policy]({{ site.baseurl }}/privacy/)
- [Terms of Use (Apple's standard EULA)](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/)
