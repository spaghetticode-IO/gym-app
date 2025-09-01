sequenceDiagram
    participant M as Member (User)
    participant UI as Frontend (Bootstrap Page)
    participant C as PHP Controller
    participant DB as MariaDB

    M->>UI: Open Classes List Page
    UI->>C: Request /classes/list.php
    C->>DB: SELECT * FROM classes WHERE date >= NOW()
    DB-->>C: Return available classes
    C-->>UI: Render class list

    M->>UI: Click "Book" for class_id=12
    UI->>C: POST /classes/book.php {class_id: 12, member_id: 101}
    C->>DB: CALL sp_check_subscription(member_id=101)
    DB-->>C: Subscription Active
    C->>DB: INSERT INTO bookings (class_id, member_id, status)
    DB-->>C: Booking Confirmed
    C-->>UI: Show "Booking Successful"
    UI-->>M: Confirmation Message
