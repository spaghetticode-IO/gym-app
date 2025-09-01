# Gym Management MVP (PHP + Bootstrap + JS + MariaDB)

🚀 مشروع MVP لنظام إدارة صالة جيم مبني باستخدام:
- **Backend:** PHP (بدون API, مباشرة مع MariaDB)
- **Frontend:** Bootstrap 5 + JS
- **Database:** MariaDB (ERD + SQL DDL + Seed + Views + Stored Procedures)
- **Architecture:** MVC بسيط (Controllers + DTOs + Views)
- **Scope:** تمثيل سنة كاملة من البيانات (Seed Data)

---

## 📌 Features
- إدارة الأعضاء (تسجيل – اشتراك – حضور)
- إدارة المدربين والحصص الرياضية
- الحجز والدفع
- لوحة تحكم إدارية (إحصائيات، إيرادات، حضور)
- تقارير جاهزة عبر **Views** و **Stored Procedures**
- بيانات Seed كاملة كأن الجيم يعمل منذ سنة

---

##  Gym Management System

| Feature / Module        | Member 👤               | Coach 🏋️                     | Admin 🛠️                             |
| ----------------------- | ----------------------- | ----------------------------- | ------------------------------------- |
| **Authentication**      | ✅ Login/Register        | ✅ Login                       | ✅ Login                               |
| Profile Management      | ✅ Edit own profile      | ✅ Edit own profile            | ✅ Manage all users                    |
| **Members Management**  | ❌                       | ❌                             | ✅ Full CRUD                           |
| **Coaches Management**  | ❌                       | ✅ Edit own data               | ✅ Full CRUD                           |
| **Classes (Sessions)**  | ✅ View & Book           | ✅ Create/Manage own           | ✅ Manage all                          |
| Book / Cancel Classes   | ✅                       | ❌                             | ✅                                     |
| View Class Schedule     | ✅                       | ✅                             | ✅                                     |
| **Attendance Tracking** | View own attendance     | ✅ Mark attendance for classes | ✅ Global Reports                      |
| **Subscriptions**       | ✅ Buy / Renew           | ❌                             | ✅ Manage plans & assign               |
| Subscription Status     | ✅ View                  | ❌                             | ✅ View/Modify                         |
| **Payments**            | ✅ Pay Online / Record   | ❌                             | ✅ Manage All Payments                 |
| Payment History         | ✅ View                  | ❌                             | ✅ Reports                             |
| **Reports & Analytics** | View own stats          | ✅ Attendance of own classes   | ✅ Revenue, Members, Global Attendance |
| **Notifications**       | ✅ Booking Confirmations | ✅ Class Reminders             | ✅ System Alerts                       |
| **Dashboard**           | ✅ Member Dashboard      | ✅ Coach Dashboard             | ✅ Admin Dashboard                     |
