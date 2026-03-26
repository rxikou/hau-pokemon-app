<?php
require __DIR__ . '/cors.php';
$conn = require __DIR__ . '/db.php';

// 1. Get ALL required fields from the Flutter App
$player_name = trim($_POST['player_name'] ?? '');
$username = trim($_POST['username'] ?? '');
$password = trim($_POST['password'] ?? '');

// 2. Check if any are missing
if ($player_name === '' || $username === '' || $password === '') {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Missing name, username, or password."]);
    exit;
}

// 3. Hash the password for security (Best Practice!)
$hashed_password = password_hash($password, PASSWORD_DEFAULT);

// 4. Insert into the database
$stmt = $conn->prepare("INSERT INTO playerstbl (player_name, username, password) VALUES (?, ?, ?)");

if (!$stmt) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database prepare failed."]);
    exit;
}

// Bind the 3 strings (s, s, s)
$stmt->bind_param('sss', $player_name, $username, $hashed_password);

if ($stmt->execute()) {
    $new_player_id = $stmt->insert_id;
    echo json_encode([
        "success" => true,
        "message" => "Welcome to the hunt, $player_name!",
        "player_id" => $new_player_id
    ]);
} else {
    // If the username is already taken, it will fail because you set it to UNIQUE (UNI)
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Registration failed. Username might be taken."]);
}

$stmt->close();
$conn->close();
?>