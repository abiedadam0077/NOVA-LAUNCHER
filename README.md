# NOVA Launcher — Minecraft Java Edition for Android

A Premium Minecraft Java Launcher for Android.
Flutter + Kotlin native integration, Midnight Navy / Electric Blue / Violet identity,
real downloads from official Mojang servers, and a bridge to open-source Android
Minecraft runtimes.

> المواصفات الكاملة: `NOVA_Launcher_Master_Prompt.txt`
> تقرير البحث: `docs/RESEARCH.md` — تقرير الحالة: `docs/STATUS.md`

---

## الميزات (حسب الحالة في docs/STATUS.md)

- Splash حقيقية بحالة تهيئة فعلية.
- Dashboard بزر PLAY متصل بحالة التثبيت الحقيقية.
- إدارة إصدارات من Mojang Piston الرسمي (تنزيل/فحص/حذف + Fabric).
- مدير مودات: استيراد، تفعيل/تعطيل، كشف تكرار، نسخ احتياطي، كتالوج Modrinth،
  وزر OPTIMIZE MY GAME بتوافق حقيقي لكل نسخة/محمل.
- خرائط: استيراد/نسخ/استعادة/حذف.
- موارد وظلال: استيراد ZIP، قراءة pack.mcmeta، معاينة pack.png، تفعيل عبر options.txt.
- مودباكات: استيراد .mrpack مع تنزيل اعتمادياته الحقيقية.
- حسابات: ملفات محلية + تدفق Microsoft Device Code (يتطلب Azure client id).
- عارض سكن ثلاثي الأبعاد حقيقي (إسقاط متعامد + UV حقيقي).
- سيرفرات: مزامنة فعلية إلى `servers.dat` بصيغة NBT + ping حقيقي (SLP).
- NOVA SMART PERFORMANCE: بروفايلات مشتقة من مواصفات الجهاز تكتب options.txt.
- مدير ملفات حقيقي داخل الإعدادات.
- دعم عربي RTL + إنجليزي + فرنسي.

## التشغيل محلياً

```
flutter pub get
flutter run
```

## بناء APK

```
flutter build apk --release
# الناتج: build/app/outputs/flutter-apk/app-release.apk
```

أو تلقائياً عبر GitHub Actions (`.github/workflows/build-apk.yml`) الذي ينشر
Release برابط تنزيل مباشر دون أي خادم مدفوع.

## بنية المشروع

```
lib/
├── core/          الثيم والألوان والحركة والتعريب والتوجيه
├── data/          Piston / Fabric / Modrinth / Microsoft / NBT / SLP / تنزيلات / SQLite
├── domain/        الخدمات (إصدارات، مودات، خرائط، موارد، مودباكات، حسابات، سيرفرات، أداء، جسر تشغيل)
└── presentation/  الشاشات والويدجت (Flutter أصلي، لا WebView)
android/           Kotlin: قنوات منصة (معلومات الجهاز، جسر الـ runtime، تثبيت APK)
```

## كيف يعمل تشغيل Minecraft؟

NOVA يجهّز بيئة لعبة قياسية كاملة (client + libraries + assets بتحقق SHA1).
تنفيذ اللعبة على Android يتطلب JVM مُحوَّلاً + طبقات LWJGL — وهي متوفرة في
مشاريع مفتوحة المصدر (Amethyst/Pojav LGPL-3.0، Zalith/FCL GPL-3.0).
جسر `RuntimeBridge` يكتشف المحركات المثبتة ويشغّلها، ويمكنه تنزيل أحدث إصدار
من Amethyst بموافقة المستخدم. تفاصيل الدمج الكامل: `docs/EMBEDDING_RUNTIME.md`.

## الاختبارات

```
flutter test
```
تشمل: NBT roundtrip، مقارنة إصدارات، آلة حالة زر التشغيل، بروفايلات الأداء،
مدير التنزيلات (تنزيل/استئناف/تحقق/فشل)، التعريبات، واختبارات ويدجت RTL.

## التراخيص

كود NOVA: MIT. المكونات الخارجية وفق تراخيصها (انظر صفحة About داخل التطبيق).
غير تابع لـ Mojang أو Microsoft.
