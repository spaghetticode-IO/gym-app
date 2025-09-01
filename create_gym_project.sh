#!/usr/bin/env bash
set -e

ROOT="gym-app"
rm -rf "$ROOT"
mkdir -p "$ROOT"/{public,src/{Controllers,Models,DTO,Middleware,Helpers},views/layouts,config,migrations,assets/{css,js,img}}

echo "Creating files..."

# config/database.php
cat > "$ROOT/config/database.php" <<'PHP'
<?php
return [
    'host' => '127.0.0.1',
    'dbname' => 'gym_mvp',
    'user' => 'root',
    'password' => '',
    'charset' => 'utf8mb4'
];
PHP

# src/Models/DB.php
cat > "$ROOT/src/Models/DB.php" <<'PHP'
<?php
class DB {
    private static $instance = null;
    public static function connect() {
        if (self::$instance === null) {
            $config = require __DIR__ . '/../../config/database.php';
            $dsn = "mysql:host={$config['host']};dbname={$config['dbname']};charset={$config['charset']}";
            self::$instance = new PDO($dsn, $config['user'], $config['password'], [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
            ]);
        }
        return self::$instance;
    }
}
PHP

# src/DTO/UserDTO.php
cat > "$ROOT/src/DTO/UserDTO.php" <<'PHP'
<?php
class UserDTO {
    public ?int $id;
    public string $email;
    public string $name;
    public string $role;

    public function __construct(array $row) {
        $this->id = $row['id'] ?? null;
        $this->email = $row['email'] ?? '';
        $this->name = $row['name'] ?? '';
        $this->role = $row['role'] ?? 'member';
    }
}
PHP

# src/Controllers/AuthController.php
cat > "$ROOT/src/Controllers/AuthController.php" <<'PHP'
<?php
require_once __DIR__ . '/../Models/DB.php';
require_once __DIR__ . '/../DTO/UserDTO.php';

class AuthController {
    private $db;
    public function __construct(){
        $this->db = DB::connect();
    }

    public function attemptLogin($email, $password){
        $stmt = $this->db->prepare("SELECT * FROM users WHERE email = :e LIMIT 1");
        $stmt->execute([':e'=>$email]);
        $user = $stmt->fetch();
        if(!$user) return false;
        if(password_verify($password, $user['password'])){
            $_SESSION['user'] = new UserDTO($user);
            return true;
        }
        return false;
    }

    public function register($data){
        $stmt = $this->db->prepare("INSERT INTO users (email, password, name, phone, role, created_at) VALUES (:e, :p, :n, :ph, :r, NOW())");
        $hash = password_hash($data['password'], PASSWORD_BCRYPT);
        $stmt->execute([
            ':e'=>$data['email'],
            ':p'=>$hash,
            ':n'=>$data['name'],
            ':ph'=>$data['phone'] ?? null,
            ':r'=>'member'
        ]);
        return $this->db->lastInsertId();
    }

    public function logout(){
        session_unset();
        session_destroy();
    }
}
PHP

# src/Controllers/ClassController.php
cat > "$ROOT/src/Controllers/ClassController.php" <<'PHP'
<?php
require_once __DIR__ . '/../Models/DB.php';

class ClassController {
    private $db;
    public function __construct(){ $this->db = DB::connect(); }

    public function getUpcoming($limit=50){
        $stmt = $this->db->prepare("SELECT c.*, co.user_id AS coach_user_id, u.name AS coach_name FROM classes c JOIN coaches co ON c.coach_id = co.id JOIN users u ON co.user_id = u.id WHERE c.start_at >= NOW() ORDER BY c.start_at ASC LIMIT :l");
        $stmt->bindValue(':l', (int)$limit, PDO::PARAM_INT);
        $stmt->execute();
        return $stmt->fetchAll();
    }

    public function getById($id){
        $stmt = $this->db->prepare("SELECT c.*, co.user_id AS coach_user_id, u.name AS coach_name FROM classes c JOIN coaches co ON c.coach_id = co.id JOIN users u ON co.user_id = u.id WHERE c.id = :id LIMIT 1");
        $stmt->execute([':id'=>$id]);
        return $stmt->fetch();
    }
}
PHP

# src/Controllers/BookingController.php
cat > "$ROOT/src/Controllers/BookingController.php" <<'PHP'
<?php
require_once __DIR__ . '/../Models/DB.php';

class BookingController {
    private $db;
    public function __construct(){ $this->db = DB::connect(); }

    public function book($userId, $classId){
        try {
            $this->db->beginTransaction();
            // capacity check
            $stmt = $this->db->prepare("SELECT c.capacity, COUNT(b.id) as booked FROM classes c LEFT JOIN bookings b ON c.id = b.class_id AND b.status='confirmed' WHERE c.id = :cid GROUP BY c.capacity");
            $stmt->execute([':cid'=>$classId]);
            $row = $stmt->fetch();
            $booked = $row['booked'] ?? 0;
            $capacity = $row['capacity'] ?? 0;
            if($capacity && $booked >= $capacity){
                $this->db->rollBack();
                return ['error'=>'Class full'];
            }
            $ins = $this->db->prepare("INSERT INTO bookings (user_id, class_id, status, created_at) VALUES (:u, :c, 'confirmed', NOW())");
            $ins->execute([':u'=>$userId, ':c'=>$classId]);
            $this->db->commit();
            return ['ok'=>true];
        } catch(Exception $e){
            $this->db->rollBack();
            return ['error'=>$e->getMessage()];
        }
    }

    public function myBookings($userId){
        $stmt = $this->db->prepare("SELECT b.*, c.title, c.start_at FROM bookings b JOIN classes c ON b.class_id = c.id WHERE b.user_id = :u ORDER BY c.start_at DESC");
        $stmt->execute([':u'=>$userId]);
        return $stmt->fetchAll();
    }
}
PHP

# src/Middleware/AuthMiddleware.php
cat > "$ROOT/src/Middleware/AuthMiddleware.php" <<'PHP'
<?php
function ensureLoggedIn(){
    session_start();
    if(!isset($_SESSION['user'])){
        header('Location: /login.php');
        exit;
    }
}
function ensureRole($role){
    session_start();
    if(!isset($_SESSION['user']) || $_SESSION['user']->role !== $role){
        header('HTTP/1.1 403 Forbidden');
        echo "Forbidden";
        exit;
    }
}
PHP

# views/layouts/header.php
cat > "$ROOT/views/layouts/header.php" <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Gym MVP</title>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
  <link href="/assets/css/style.css" rel="stylesheet">
</head>
<body>
<nav class="navbar navbar-expand-lg navbar-dark bg-dark">
  <div class="container-fluid">
    <a class="navbar-brand" href="/">Gym</a>
    <div class="collapse navbar-collapse">
      <ul class="navbar-nav ms-auto">
<?php if(isset($_SESSION['user'])): ?>
  <li class="nav-item"><a class="nav-link" href="/classes.php">Classes</a></li>
  <?php if($_SESSION['user']->role === 'coach'): ?>
    <li class="nav-item"><a class="nav-link" href="/coach/dashboard.php">Coach</a></li>
  <?php endif; ?>
  <?php if($_SESSION['user']->role === 'admin'): ?>
    <li class="nav-item"><a class="nav-link" href="/admin/dashboard.php">Admin</a></li>
  <?php endif; ?>
  <li class="nav-item"><a class="nav-link" href="/profile.php">Profile</a></li>
  <li class="nav-item"><a class="nav-link" href="/logout.php">Logout</a></li>
<?php else: ?>
  <li class="nav-item"><a class="nav-link" href="/login.php">Login</a></li>
  <li class="nav-item"><a class="nav-link" href="/register.php">Register</a></li>
<?php endif; ?>
      </ul>
    </div>
  </div>
</nav>
<div class="container mt-4">
HTML

# views/layouts/footer.php
cat > "$ROOT/views/layouts/footer.php" <<'HTML'
</div>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
<script src="/assets/js/app.js"></script>
</body>
</html>
HTML

# public/index.php
cat > "$ROOT/public/index.php" <<'PHP'
<?php
session_start();
require_once __DIR__ . '/../src/Models/DB.php';
include __DIR__ . '/../views/layouts/header.php';
?>
<div class="p-4 bg-light rounded">
  <h1>Welcome to Gym MVP</h1>
  <p>Simple PHP + Bootstrap MVP. Use the menu to explore classes, bookings and admin/coach panels.</p>
  <a class="btn btn-primary" href="/classes.php">View Classes</a>
</div>
<?php include __DIR__ . '/../views/layouts/footer.php'; ?>
PHP

# public/login.php
cat > "$ROOT/public/login.php" <<'PHP'
<?php
session_start();
require_once __DIR__ . '/../src/Controllers/AuthController.php';
$auth = new AuthController();
$err = null;
if($_SERVER['REQUEST_METHOD'] === 'POST'){
    $email = $_POST['email'] ?? '';
    $pass = $_POST['password'] ?? '';
    if($auth->attemptLogin($email, $pass)){
        header('Location: /');
        exit;
    } else {
        $err = "Invalid credentials";
    }
}
include __DIR__ . '/../views/layouts/header.php';
?>
<div class="row justify-content-center">
  <div class="col-md-5">
    <h3>Login</h3>
    <?php if($err): ?><div class="alert alert-danger"><?=htmlspecialchars($err)?></div><?php endif;?>
    <form method="post">
      <div class="mb-3"><label>Email</label><input class="form-control" name="email" required></div>
      <div class="mb-3"><label>Password</label><input type="password" class="form-control" name="password" required></div>
      <button class="btn btn-primary">Login</button>
    </form>
  </div>
</div>
<?php include __DIR__ . '/../views/layouts/footer.php'; ?>
PHP

# public/register.php
cat > "$ROOT/public/register.php" <<'PHP'
<?php
session_start();
require_once __DIR__ . '/../src/Controllers/AuthController.php';
$auth = new AuthController();
$err = null;
if($_SERVER['REQUEST_METHOD'] === 'POST'){
    $data = [
        'email'=>$_POST['email'],
        'password'=>$_POST['password'],
        'name'=>$_POST['name'],
        'phone'=>$_POST['phone'] ?? null
    ];
    try{
        $id = $auth->register($data);
        header('Location: /login.php');
        exit;
    } catch(Exception $e){
        $err = $e->getMessage();
    }
}
include __DIR__ . '/../views/layouts/header.php';
?>
<div class="row justify-content-center">
  <div class="col-md-6">
    <h3>Register</h3>
    <?php if($err): ?><div class="alert alert-danger"><?=htmlspecialchars($err)?></div><?php endif;?>
    <form method="post">
      <div class="mb-3"><label>Name</label><input class="form-control" name="name" required></div>
      <div class="mb-3"><label>Email</label><input type="email" class="form-control" name="email" required></div>
      <div class="mb-3"><label>Phone</label><input class="form-control" name="phone"></div>
      <div class="mb-3"><label>Password</label><input type="password" class="form-control" name="password" required></div>
      <button class="btn btn-success">Register</button>
    </form>
  </div>
</div>
<?php include __DIR__ . '/../views/layouts/footer.php'; ?>
PHP

# public/logout.php
cat > "$ROOT/public/logout.php" <<'PHP'
<?php
session_start();
require_once __DIR__ . '/../src/Controllers/AuthController.php';
$auth = new AuthController();
$auth->logout();
header('Location: /');
PHP

# public/classes.php
cat > "$ROOT/public/classes.php" <<'PHP'
<?php
session_start();
require_once __DIR__ . '/../src/Controllers/ClassController.php';
$c = new ClassController();
$classes = $c->getUpcoming();
include __DIR__ . '/../views/layouts/header.php';
?>
<h3>Upcoming Classes</h3>
<div class="row">
<?php foreach($classes as $cl): ?>
  <div class="col-md-6">
    <div class="card mb-3">
      <div class="card-body">
        <h5 class="card-title"><?=htmlspecialchars($cl['title'])?></h5>
        <p class="card-text"><?=htmlspecialchars($cl['description'] ?? '')?></p>
        <p class="small">Coach: <?=htmlspecialchars($cl['coach_name'])?> | Start: <?=htmlspecialchars($cl['start_at'])?></p>
        <a href="/booking.php?class_id=<?=intval($cl['id'])?>" class="btn btn-primary">Book</a>
      </div>
    </div>
  </div>
<?php endforeach; ?>
</div>
<?php include __DIR__ . '/../views/layouts/footer.php'; ?>
PHP

# public/booking.php
cat > "$ROOT/public/booking.php" <<'PHP'
<?php
session_start();
require_once __DIR__ . '/../src/Middleware/AuthMiddleware.php';
require_once __DIR__ . '/../src/Controllers/BookingController.php';
ensureLoggedIn();
$bookCtrl = new BookingController();
$uid = $_SESSION['user']->id;
$err = null;
$msg = null;
if($_SERVER['REQUEST_METHOD'] === 'POST'){
    $class_id = (int)($_POST['class_id'] ?? 0);
    $res = $bookCtrl->book($uid, $class_id);
    if(isset($res['error'])) $err = $res['error']; else $msg = "Booked successfully";
}
$classId = (int)($_GET['class_id'] ?? 0);
include __DIR__ . '/../views/layouts/header.php';
?>
<?php if($err): ?><div class="alert alert-danger"><?=$err?></div><?php endif;?>
<?php if($msg): ?><div class="alert alert-success"><?=$msg?></div><?php endif;?>
<form method="post">
  <input type="hidden" name="class_id" value="<?=$classId?>">
  <p>هل تريد تأكيد الحجز؟</p>
  <button class="btn btn-primary">Confirm Booking</button>
  <a href="/classes.php" class="btn btn-secondary">Cancel</a>
</form>
<?php include __DIR__ . '/../views/layouts/footer.php'; ?>
PHP

# public/profile.php
cat > "$ROOT/public/profile.php" <<'PHP'
<?php
session_start();
require_once __DIR__ . '/../src/Middleware/AuthMiddleware.php';
require_once __DIR__ . '/../src/Controllers/BookingController.php';
ensureLoggedIn();
$bookCtrl = new BookingController();
$bookings = $bookCtrl->myBookings($_SESSION['user']->id);
include __DIR__ . '/../views/layouts/header.php';
?>
<h3>Profile: <?=htmlspecialchars($_SESSION['user']->name)?></h3>
<p>Role: <?=htmlspecialchars($_SESSION['user']->role)?></p>

<h4>My Bookings</h4>
<ul class="list-group">
<?php foreach($bookings as $b): ?>
  <li class="list-group-item">
    <?=htmlspecialchars($b['title'])?> — <?=htmlspecialchars($b['start_at'])?> — <?=htmlspecialchars($b['status'])?>
  </li>
<?php endforeach; ?>
</ul>

<?php include __DIR__ . '/../views/layouts/footer.php'; ?>
PHP

# public/coach/dashboard.php
mkdir -p "$ROOT/public/coach"
cat > "$ROOT/public/coach/dashboard.php" <<'PHP'
<?php
session_start();
require_once __DIR__ . '/../../src/Middleware/AuthMiddleware.php';
ensureLoggedIn();
if($_SESSION['user']->role !== 'coach'){ header('Location: /'); exit; }
include __DIR__ . '/../../views/layouts/header.php';
?>
<h3>Coach Dashboard (basic)</h3>
<p>Coming soon: class management, attendance.</p>
<?php include __DIR__ . '/../../views/layouts/footer.php'; ?>
PHP

# public/admin/dashboard.php
mkdir -p "$ROOT/public/admin"
cat > "$ROOT/public/admin/dashboard.php" <<'PHP'
<?php
session_start();
require_once __DIR__ . '/../../src/Middleware/AuthMiddleware.php';
ensureLoggedIn();
if($_SESSION['user']->role !== 'admin'){ header('Location: /'); exit; }
include __DIR__ . '/../../views/layouts/header.php';
?>
<h3>Admin Dashboard (basic)</h3>
<p>Use the SQL reports or future admin pages for management.</p>
<?php include __DIR__ . '/../../views/layouts/footer.php'; ?>
PHP

# assets simple
cat > "$ROOT/assets/css/style.css" <<'CSS'
body{padding-bottom:40px}
CSS

cat > "$ROOT/assets/js/app.js" <<'JS'
console.log('Gym MVP JS loaded');
JS

# migrations/schema.sql (from earlier)
cat > "$ROOT/migrations/schema.sql" <<'SQL'
-- CREATE DATABASE
CREATE DATABASE IF NOT EXISTS gym_mvp
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE gym_mvp;

CREATE TABLE users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  password VARCHAR(255) NOT NULL,
  name VARCHAR(150) NOT NULL,
  phone VARCHAR(30),
  role ENUM('member','coach','admin') DEFAULT 'member',
  avatar VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE coaches (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNIQUE NOT NULL,
  bio TEXT,
  specialties VARCHAR(255),
  hourly_rate DECIMAL(8,2) DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE classes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  coach_id INT NOT NULL,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  start_at DATETIME NOT NULL,
  duration_min INT NOT NULL,
  capacity INT DEFAULT 20,
  price DECIMAL(8,2) DEFAULT 0,
  location VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (coach_id) REFERENCES coaches(id) ON DELETE CASCADE
);

CREATE TABLE bookings (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  class_id INT NOT NULL,
  status ENUM('pending','confirmed','cancelled') DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_user_class (user_id, class_id),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE CASCADE
);

CREATE TABLE attendance (
  id INT AUTO_INCREMENT PRIMARY KEY,
  booking_id INT NOT NULL,
  status ENUM('present','absent') DEFAULT 'absent',
  checked_in_at DATETIME,
  FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE
);

CREATE TABLE subscriptions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  type VARCHAR(100),
  start_date DATE,
  end_date DATE,
  status ENUM('active','expired','cancelled') DEFAULT 'active',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE payments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  method VARCHAR(50),
  status ENUM('pending','success','failed') DEFAULT 'pending',
  gateway_ref VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX idx_classes_start ON classes(start_at);
CREATE INDEX idx_bookings_user ON bookings(user_id);
CREATE INDEX idx_bookings_class ON bookings(class_id);
CREATE INDEX idx_subscriptions_user ON subscriptions(user_id);
CREATE INDEX idx_payments_user ON payments(user_id);
SQL

# migrations/seed.sql (condensed demo seed; passwords are plain 'secret' hashed example)
cat > "$ROOT/migrations/seed.sql" <<'SQL'
USE gym_mvp;

INSERT INTO users (email, password, name, phone, role, created_at) VALUES
('admin@gym.com', '$2y$10$KmHjzq6Qy8QbZk9Yp8hEjeQHf3R2uYp3xV4jS1QYxq1e6f1QfA5b2', 'Super Admin', '0100000000', 'admin', '2024-09-01 09:00:00'),
('coach1@gym.com', '$2y$10$KmHjzq6Qy8QbZk9Yp8hEjeQHf3R2uYp3xV4jS1QYxq1e6f1QfA5b2', 'Coach Ahmed', '0100000001', 'coach', '2024-09-02 10:00:00'),
('coach2@gym.com', '$2y$10$KmHjzq6Qy8QbZk9Yp8hEjeQHf3R2uYp3xV4jS1QYxq1e6f1QfA5b2', 'Coach Sara', '0100000002', 'coach', '2024-09-03 10:30:00'),
('member1@gym.com', '$2y$10$KmHjzq6Qy8QbZk9Yp8hEjeQHf3R2uYp3xV4jS1QYxq1e6f1QfA5b2', 'Ali Hassan', '0100000003', 'member', '2024-09-05 11:00:00'),
('member2@gym.com', '$2y$10$KmHjzq6Qy8QbZk9Yp8hEjeQHf3R2uYp3xV4jS1QYxq1e6f1QfA5b2', 'Mona Ibrahim', '0100000004', 'member', '2024-09-05 11:05:00'),
('member3@gym.com', '$2y$10$KmHjzq6Qy8QbZk9Yp8hEjeQHf3R2uYp3xV4jS1QYxq1e6f1QfA5b2', 'Khaled Youssef', '0100000005', 'member', '2024-09-06 12:00:00'),
('member4@gym.com', '$2y$10$KmHjzq6Qy8QbZk9Yp8hEjeQHf3R2uYp3xV4jS1QYxq1e6f1QfA5b2', 'Laila Mostafa', '0100000006', 'member', '2024-09-06 12:10:00'),
('member5@gym.com', '$2y$10$KmHjzq6Qy8QbZk9Yp8hEjeQHf3R2uYp3xV4jS1QYxq1e6f1QfA5b2', 'Omar Adel', '0100000007', 'member', '2024-09-07 13:00:00');

INSERT INTO coaches (user_id, bio, specialties, hourly_rate, created_at) VALUES
(2, '10 سنوات خبرة في التدريب الشخصي.', 'Strength, Cardio', 200, '2024-09-02 10:00:00'),
(3, 'مدربة متخصصة في اليوغا والبيلاتس.', 'Yoga, Pilates', 180, '2024-09-03 10:30:00');

INSERT INTO classes (coach_id, title, description, start_at, duration_min, capacity, price, location, created_at) VALUES
(1, 'Strength Training', 'تمارين قوة للمستوى المتوسط', '2024-09-10 18:00:00', 60, 20, 50, 'Hall A', '2024-09-01 09:00:00'),
(2, 'Morning Yoga', 'يوغا صباحية لزيادة المرونة', '2024-09-12 07:30:00', 45, 15, 40, 'Studio 1', '2024-09-02 09:00:00'),
(1, 'Cardio Blast', 'جلسة كارديو مكثفة', '2024-10-05 19:00:00', 50, 25, 60, 'Hall B', '2024-09-20 09:00:00'),
(2, 'Pilates Basics', 'أساسيات البيلاتس', '2024-11-02 17:00:00', 60, 20, 45, 'Studio 2', '2024-10-01 09:00:00'),
(1, 'Power Lifting', 'رفع أثقال متقدم', '2025-01-15 18:30:00', 90, 10, 100, 'Hall A', '2024-12-01 09:00:00'),
(2, 'Yoga Flow', 'تدفق يوغا للمتوسطين', '2025-02-10 08:00:00', 60, 20, 50, 'Studio 1', '2025-01-01 09:00:00'),
(1, 'HIIT Session', 'تمارين HIIT لحرق الدهون', '2025-04-20 18:00:00', 45, 25, 70, 'Hall B', '2025-03-01 09:00:00'),
(2, 'Advanced Pilates', 'بيلاتس متقدم', '2025-06-05 17:00:00', 60, 15, 60, 'Studio 2', '2025-05-01 09:00:00'),
(1, 'Strength Endurance', 'تحمل العضلات والقوة', '2025-08-15 19:00:00', 60, 20, 55, 'Hall A', '2025-07-01 09:00:00'),
(2, 'Sunrise Yoga', 'يوغا عند شروق الشمس', '2025-09-02 06:30:00', 60, 20, 45, 'Studio 1', '2025-08-01 09:00:00');

INSERT INTO bookings (user_id, class_id, status, created_at) VALUES
(4, 1, 'confirmed', '2024-09-09 12:00:00'),
(5, 2, 'confirmed', '2024-09-11 12:00:00'),
(6, 3, 'cancelled', '2024-10-01 12:00:00'),
(7, 4, 'confirmed', '2024-11-01 12:00:00'),
(8, 5, 'confirmed', '2025-01-10 12:00:00'),
(4, 6, 'confirmed', '2025-02-05 12:00:00'),
(5, 7, 'pending',   '2025-04-15 12:00:00'),
(6, 8, 'confirmed', '2025-06-01 12:00:00'),
(7, 9, 'confirmed', '2025-08-10 12:00:00'),
(8, 10, 'pending',  '2025-08-25 12:00:00');

INSERT INTO attendance (booking_id, status, checked_in_at) VALUES
(1, 'present', '2024-09-10 18:05:00'),
(2, 'present', '2024-09-12 07:35:00'),
(3, 'absent', NULL),
(4, 'present', '2024-11-02 17:05:00'),
(5, 'present', '2025-01-15 18:35:00');

INSERT INTO subscriptions (user_id, type, start_date, end_date, status, created_at) VALUES
(4, 'Yearly', '2024-09-05', '2025-09-04', 'active', '2024-09-05 12:00:00'),
(5, 'Monthly', '2024-09-05', '2024-10-04', 'expired', '2024-09-05 12:05:00'),
(6, '6-Months', '2024-10-01', '2025-03-31', 'expired', '2024-10-01 13:00:00'),
(7, 'Monthly', '2025-07-01', '2025-07-31', 'expired', '2025-07-01 14:00:00'),
(8, 'Yearly', '2025-01-01', '2025-12-31', 'active', '2025-01-01 10:00:00');

INSERT INTO payments (user_id, amount, method, status, gateway_ref, created_at) VALUES
(4, 1200.00, 'cash', 'success', 'SUB-YEARLY-2024', '2024-09-05 12:10:00'),
(5, 100.00, 'card', 'success', 'SUB-MONTH-2024', '2024-09-05 12:15:00'),
(6, 500.00, 'paypal', 'success', 'SUB-6M-2024', '2024-10-01 13:05:00'),
(7, 100.00, 'card', 'failed', 'SUB-MONTH-2025', '2025-07-01 14:10:00'),
(8, 1200.00, 'card', 'success', 'SUB-YEARLY-2025', '2025-01-01 10:05:00');
SQL

# reports (views + procedures)
cat > "$ROOT/migrations/schema_reports.sql" <<'SQL'
USE gym_mvp;
CREATE OR REPLACE VIEW vw_class_overview AS
SELECT c.id AS class_id, c.title, c.start_at, c.location, u.name AS coach_name, c.capacity, COUNT(b.id) AS total_bookings, (c.capacity - COUNT(b.id)) AS seats_left
FROM classes c JOIN coaches co ON c.coach_id = co.id JOIN users u ON co.user_id = u.id LEFT JOIN bookings b ON c.id = b.class_id AND b.status = 'confirmed'
GROUP BY c.id, c.title, c.start_at, c.location, u.name, c.capacity;

CREATE OR REPLACE VIEW vw_active_members AS
SELECT u.id AS member_id, u.name, u.email, s.type AS subscription_type, s.start_date, s.end_date, s.status
FROM users u JOIN subscriptions s ON u.id = s.user_id
WHERE u.role = 'member' AND s.status = 'active';

CREATE OR REPLACE VIEW vw_monthly_revenue AS
SELECT DATE_FORMAT(p.created_at, '%Y-%m') AS month, SUM(p.amount) AS total_revenue, COUNT(p.id) AS total_transactions
FROM payments p WHERE p.status = 'success' GROUP BY DATE_FORMAT(p.created_at, '%Y-%m');

CREATE OR REPLACE VIEW vw_member_attendance AS
SELECT u.id AS member_id, u.name, COUNT(a.id) AS attended_sessions
FROM attendance a JOIN bookings b ON a.booking_id = b.id JOIN users u ON b.user_id = u.id WHERE a.status = 'present' GROUP BY u.id, u.name;

CREATE OR REPLACE VIEW vw_attendance_rate AS
SELECT u.id AS member_id, u.name, SUM(CASE WHEN a.status = 'present' THEN 1 ELSE 0 END) AS presents, SUM(CASE WHEN a.status = 'absent' THEN 1 ELSE 0 END) AS absents, ROUND(100.0 * SUM(CASE WHEN a.status = 'present' THEN 1 ELSE 0 END) / COUNT(a.id), 2) AS attendance_rate
FROM attendance a JOIN bookings b ON a.booking_id = b.id JOIN users u ON b.user_id = u.id GROUP BY u.id, u.name;

CREATE OR REPLACE VIEW vw_expired_subscriptions AS
SELECT u.id, u.name, u.email, s.type, s.end_date FROM users u JOIN subscriptions s ON u.id = s.user_id WHERE s.status = 'expired';

CREATE OR REPLACE VIEW vw_revenue_by_subscription AS
SELECT s.type AS subscription_type, SUM(p.amount) AS revenue FROM subscriptions s JOIN payments p ON s.user_id = p.user_id WHERE p.status = 'success' GROUP BY s.type;

DELIMITER //
CREATE PROCEDURE sp_revenue_range(IN start_date DATE, IN end_date DATE)
BEGIN
    SELECT DATE_FORMAT(p.created_at, '%Y-%m-%d') AS day, SUM(p.amount) AS total_revenue, COUNT(p.id) AS transactions
    FROM payments p
    WHERE p.status = 'success' AND p.created_at BETWEEN start_date AND end_date
    GROUP BY DATE_FORMAT(p.created_at, '%Y-%m-%d');
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_member_attendance(IN member_id INT, IN start_date DATE, IN end_date DATE)
BEGIN
    SELECT u.id, u.name, c.title AS class_title, a.status, a.checked_in_at
    FROM attendance a JOIN bookings b ON a.booking_id = b.id JOIN users u ON b.user_id = u.id JOIN classes c ON b.class_id = c.id
    WHERE u.id = member_id AND c.start_at BETWEEN start_date AND end_date
    ORDER BY c.start_at DESC;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_top_classes(IN top_n INT)
BEGIN
    SELECT c.title, u.name AS coach_name, COUNT(b.id) AS total_confirmed_bookings
    FROM classes c JOIN coaches co ON c.coach_id = co.id JOIN users u ON co.user_id = u.id JOIN bookings b ON c.id = b.class_id
    WHERE b.status = 'confirmed'
    GROUP BY c.title, u.name
    ORDER BY total_confirmed_bookings DESC LIMIT top_n;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_expiring_subscriptions(IN within_days INT)
BEGIN
    SELECT u.id, u.name, u.email, s.type, s.end_date
    FROM users u JOIN subscriptions s ON u.id = s.user_id
    WHERE s.status = 'active' AND s.end_date BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL within_days DAY)
    ORDER BY s.end_date ASC;
END //
DELIMITER ;
SQL

# README
cat > "$ROOT/README.md" <<'MD'
# Gym MVP (PHP + Bootstrap)

## Quick Start

1. Create DB and import schema:
   mysql -u root -p < migrations/schema.sql
2. Import seed data:
   mysql -u root -p gym_mvp < migrations/seed.sql
3. Optionally load reports (views & procedures):
   mysql -u root -p gym_mvp < migrations/schema_reports.sql
4. Run PHP built-in server:
   php -S localhost:8000 -t public
5. Open http://localhost:8000

Default users:
- admin@gym.com (password: secret)  -- role: admin
- coach1@gym.com (secret) -- role: coach
- member1@gym.com (secret) -- role: member

**Note:** Password hashes in seed are bcrypt of "secret". Replace DB credentials in config/database.php if needed.
MD

echo "Zipping..."
zip -r "${ROOT}.zip" "$ROOT" > /dev/null
echo "Done: ${ROOT}.zip"
