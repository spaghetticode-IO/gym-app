/public
│
├── index.php             # الصفحة الرئيسية (Login / Register)
├── dashboard.php         # لوحة التحكم (Admin / Coach / Member Dashboard)
│
├── auth/
│   ├── login.php         # تسجيل دخول
│   ├── logout.php        # تسجيل خروج
│   └── register.php      # إنشاء حساب عضو
│
├── members/
│   ├── list.php          # عرض كل الأعضاء
│   ├── profile.php       # ملف شخصي لعضو
│   ├── add.php           # إضافة عضو جديد (من Admin)
│   ├── edit.php          # تعديل بيانات عضو
│   └── delete.php        # حذف عضو
│
├── coaches/
│   ├── list.php          # عرض المدربين
│   ├── profile.php       # ملف مدرب
│   ├── add.php
│   ├── edit.php
│   └── delete.php
│
├── classes/
│   ├── list.php          # عرض جميع الحصص
│   ├── details.php       # تفاصيل الحصة (Coach, Capacity, Time)
│   ├── book.php          # حجز عضو في الحصة
│   ├── cancel.php        # إلغاء الحجز
│   └── manage.php        # (Coach) إدارة الحصص الخاصة به
│
├── attendance/
│   ├── mark.php          # تسجيل حضور/غياب
│   ├── report.php        # تقارير الحضور
│
├── subscriptions/
│   ├── list.php          # جميع الاشتراكات
│   ├── add.php           # شراء اشتراك جديد
│   ├── renew.php         # تجديد
│   └── expire.php        # تحديث حالة منتهية
│
├── payments/
│   ├── list.php          # قائمة المدفوعات
│   ├── pay.php           # تنفيذ الدفع
│   └── history.php       # سجل المدفوعات
│
├── reports/
│   ├── revenue.php       # تقرير الإيرادات
│   ├── attendance.php    # تقرير الحضور
│   ├── members.php       # تقرير الأعضاء النشطين
│   └── subscriptions.php # الاشتراكات المنتهية / النشطة
│
└── assets/
    ├── css/
    ├── js/
    └── images/
