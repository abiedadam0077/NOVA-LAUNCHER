# دمج محرك تشغيل Minecraft داخل NOVA (الحالة: سقالة موثقة)

## لماذا لا نبني المحرك من الصفر؟
تشغيل Minecraft Java على Android يتطلب: OpenJDK مُحوَّلاً لأنظمة ARM، طبقة
LWJGL3-glfw shim، مترجمات رسوميات (ANGLE/VirGL/gl4es)، ومكونات AWT
(caciocavallo). هذا عمل مشاريع كاملة (Pojav/Amethyst LGPL-3.0، Zalith/FCL GPL-3.0).
إعادة كتابته غير واقعية وغير ضرورية قانونياً بفضل التراخيص المفتوحة.

## المسار المعتمد حالياً (فعّال)
1. NOVA يجهّز ملفات اللعبة الرسمية الكاملة بتحقق SHA1.
2. `RuntimeBridge` (lib/domain/runtime_bridge.dart + Kotlin `nova/app` channel):
   - يكتشف المحركات المثبتة (Pojav/Zalith/FCL/Amethyst).
   - يشغّلها ويمرر `nova_version` و`nova_gamedir` كـ extras.
   - ينزّل أحدث APK لـ Amethyst من GitHub Releases ويثبّته بموافقة المستخدم.

## مسار الدمج الكامل (خطوات التنفيذ المستقبلية)
1. إضافة Amethyst-Android كـ submodule.
2. تحويل `app_pojavlauncher` إلى وحدة library وضمها في `android/settings.gradle`.
3. بناء مكونات NDK (تتوفر AARs مبنية مسبقاً داخل مستودعهم: SDL/ANGLE/lwjgl-natives).
4. جلب أصول JRE من إصدارات `universal-minecraft-runtime` (~200MB) ووضعها في assets.
5. استبدال شاشة التشغيل باستدعاء `LauncherActivity` الخاص بهم مباشرة.

## سبب عدم تنفيذ الدمج الكامل في هذه الدورة
- يتطلب سلاسل أدوات NDK وأصولاً ثنائية كبيرة غير قابلة للإنتاج في بيئة العمل
  الحالية، ويزيد حجم APK لأكثر من 200MB.
- تم تفضيل مسار الجسر ليظل التطبيق خفيفاً ومبنياً ومختبراً، مع بقاء بنية
  الدمج جاهزة وموثقة هنا. الحالة موثقة في docs/STATUS.md بشفافية.
