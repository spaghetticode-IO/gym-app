flowchart TD

%% Users
A[Member] -->|Login / Book Class| B[PHP Controllers]
C[Coach] -->|Manage Classes / Attendance| B
D[Admin] -->|Manage Users / Reports| B

%% Controllers Layer
B[PHP Controllers] --> E[DTOs / Business Logic]

%% Database Layer
E --> F[(MariaDB Database)]

%% DB Details
F -->|Tables| F1[Members\nCoaches\nClasses\nSubscriptions\nPayments\nAttendance\nBookings]
F -->|Stored Procedures| F2[sp_member_attendance\nsp_top_classes\nsp_revenue_report]
F -->|Views| F3[v_active_members\nv_revenue_summary\nv_attendance_stats]

%% UI Layer
B --> G[Bootstrap + JS (Frontend Pages)]
