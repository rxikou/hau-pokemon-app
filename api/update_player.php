<?php
require __DIR__ . '/cors.php';
$conn = require __DIR__ . '/db.php';

$player_id = intval($_POST['player_id'] ?? 0);
$player_name = trim($_POST['player_name'] ?? '');
$username = trim($_POST['username'] ?? '');
$password = trim($_POST['password'] ?? '');

if ($player_id <= 0 || $player_name === '' || $username === '') {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "message" => "Missing player_id, player_name, or username."
    ]);
    exit;
}

// Ensure target account exists.
$exists_stmt = $conn->prepare("SELECT player_id FROM playerstbl WHERE player_id = ? LIMIT 1");
if (!$exists_stmt) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database prepare failed."]);
    exit;
}
$exists_stmt->bind_param('i', $player_id);
$exists_stmt->execute();
$exists_res = $exists_stmt->get_result();
if (!$exists_res || $exists_res->num_rows === 0) {
    http_response_code(404);
    echo json_encode(["success" => false, "message" => "Player not found."]);
    $exists_stmt->close();
    $conn->close();
    exit;
}
$exists_stmt->close();

// Prevent username collisions.
$dupe_stmt = $conn->prepare("SELECT player_id FROM playerstbl WHERE username = ? AND player_id <> ? LIMIT 1");
if (!$dupe_stmt) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database prepare failed."]);
    $conn->close();
    exit;
}
$dupe_stmt->bind_param('si', $username, $player_id);
$dupe_stmt->execute();
$dupe_res = $dupe_stmt->get_result();
if ($dupe_res && $dupe_res->num_rows > 0) {
    http_response_code(409);
    echo json_encode(["success" => false, "message" => "Username already taken."]);
    $dupe_stmt->close();
    $conn->close();
    exit;
}
$dupe_stmt->close();

if ($password !== '') {
    $hashed_password = password_hash($password, PASSWORD_DEFAULT);
    $update_stmt = $conn->prepare(
        "UPDATE playerstbl SET player_name = ?, username = ?, password = ? WHERE player_id = ?"
    );
    if (!$update_stmt) {
        http_response_code(500);
        echo json_encode(["success" => false, "message" => "Database prepare failed."]);
        $conn->close();
        exit;
    }
    $update_stmt->bind_param('sssi', $player_name, $username, $hashed_password, $player_id);
} else {
    $update_stmt = $conn->prepare(
        "UPDATE playerstbl SET player_name = ?, username = ? WHERE player_id = ?"
    );
    if (!$update_stmt) {
        http_response_code(500);
        echo json_encode(["success" => false, "message" => "Database prepare failed."]);
        $conn->close();
        exit;
    }
    $update_stmt->bind_param('ssi', $player_name, $username, $player_id);
}

if ($update_stmt->execute()) {
    echo json_encode([
        "success" => true,
        "message" => "Profile updated successfully.",
        "player_id" => $player_id,
        "player_name" => $player_name,
        "username" => $username
    ]);
} else {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Update failed."]);
}

$update_stmt->close();
$conn->close();
?>
