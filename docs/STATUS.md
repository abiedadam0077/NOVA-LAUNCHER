# NOVA Launcher — تقرير الحالة النهائي (شفاف)

الحالات: `COMPLETED AND TESTED` | `IMPLEMENTED BUT NOT FULLY TESTED` |
`PARTIALLY IMPLEMENTED` | `NOT IMPLEMENTED`

## البناء والاختبار
| البند | الحالة |
|---|---|
| flutter analyze (CI) | سيُحدَّث بعد دورة CI |
| flutter test (CI) | سيُحدَّث بعد دورة CI |
| بناء Release APK (CI) | سيُحدَّث بعد دورة CI |
| تثبيت/تشغيل على جهاز حقيقي | NOT IMPLEMENTED — لا يتوفر جهاز في بيئة العمل (يُذكر بصدق وفق §27) |
| تشغيل Minecraft فعلياً على جهاز | NOT IMPLEMENTED هنا — يتطلب جهازاً؛ المسار الموثق: RuntimeBridge + محرك مثبّت |

## الميزات
| الميزة | الحالة | ملاحظات |
|---|---|---|
| Splash بحالة حقيقية | COMPLETED AND TESTED (widget/UI) | دون انتظار مصطنع |
| Dashboard + زر PLAY بحالات حقيقية | COMPLETED (منطق مُختبر بوحدة) | |
| Floating Bottom Nav + RTL | COMPLETED (widget tests) | |
| إدارة الإصدارات (Piston) | IMPLEMENTED BUT NOT FULLY TESTED | تنزيل/فحص/حذف حقيقي؛ يُختبر على جهاز |
| Fabric | IMPLEMENTED BUT NOT FULLY TESTED | profile حقيقي من meta.fabricmc.net |
| Forge/NeoForge/Quilt | PARTIALLY IMPLEMENTED | عرض/تنزيل دون تنفيذ مثبّتاتها (تتطلب JVM) |
| Download Manager | COMPLETED AND TESTED (وحدة) | استئناف/SHA1/إلغاء/تزامن |
| مدير المودات | IMPLEMENTED BUT NOT FULLY TESTED | استيراد/تفعيل/تكرار/نسخ احتياطي |
| كتالوج Modrinth | IMPLEMENTED | بحث/تنزيل بموافقة |
| OPTIMIZE MY GAME | IMPLEMENTED | اقتراحات متوافقة فعلياً + تراجع |
| الخرائط | IMPLEMENTED | استيراد/نسخ/استعادة/حذف |
| الموارد والظلال | IMPLEMENTED | pack.mcmeta + pack.png + options.txt |
| المودباكات (.mrpack) | IMPLEMENTED | تنزيل اعتماديات حقيقي |
| حسابات محلية | COMPLETED | |
| Microsoft Auth | PARTIALLY IMPLEMENTED | تدفق جهاز كامل؛ يتطلب Azure client id مسجلاً |
| عارض سكن 3D | COMPLETED (widget) | إسقاط متعامد حقيقي |
| السيرفرات + servers.dat | COMPLETED AND TESTED (NBT roundtrip) | SLP ping حقيقي |
| NOVA SMART PERFORMANCE | COMPLETED (وحدة للبروفايلات) | يكتب options.txt فعلياً |
| مدير الملفات | IMPLEMENTED | ضمن الإعدادات |
| سجلات الأخطاء والتحليل | IMPLEMENTED | heuristics موثقة + تصدير |
| Work offline | IMPLEMENTED | كاش manifest + بيانات محلية |
| دمج محرك تشغيل مضمّن | PARTIALLY IMPLEMENTED | جسر فعّال + توثيق دمج كامل |

## مشاكل معروفة
- لا يمكن اختبار إقلاع اللعبة دون جهاز Android فعلي.
- مصادقة Microsoft تتطلب تسجيل Azure خاص بالمستخدم/المطوّر.
