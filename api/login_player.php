<?php
require __DIR__ . '/cors.php';
$conn = require __DIR__ . '/db.php';

// 1. Get the login details from the app
$username = trim($_POST['username'] ?? '');
$password = trim($_POST['password'] ?? '');

if ($username === '' || $password === '') {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Missing username or password."]);
    exit;
}

// 2. Find the user in the database
$stmt = $conn->prepare("SELECT player_id, player_name, password FROM playerstbl WHERE username = ?");

if (!$stmt) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database prepare failed."]);
    exit;
}

$stmt->bind_param('s', $username);
$stmt->execute();
$result = $stmt->get_result();

// 3. Verify the user exists and the password matches
if ($result && $result->num_rows > 0) {
    $user = $result->fetch_assoc();
    
    // Check the hashed password against what they typed
    if (password_verify($password, $user['password'])) {
        echo json_encode([
            "success" => true,
            "message" => "Welcome back, " . $user['player_name'] . "!",
            "player_id" => (int)$user['player_id'],
            "player_name" => $user['player_name']
        ]);
    } else {
        http_response_code(401); // 401 Unauthorized
        echo json_encode(["success" => false, "message" => "Incorrect password."]);
    }
} else {
    http_response_code(404); // 404 Not Found
    echo json_encode(["success" => false, "message" => "Username not found."]);
}

$stmt->close();
$conn->close();
?>