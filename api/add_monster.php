<?php
require __DIR__ . '/cors.php';
$conn = require __DIR__ . '/db.php';

// Accept both REST-ish keys and DB column keys.
$name = trim($_POST['monster_name'] ?? $_POST['name'] ?? '');
$type = trim($_POST['monster_type'] ?? $_POST['type'] ?? '');
$lat = $_POST['spawn_latitude'] ?? $_POST['latitude'] ?? $_POST['lat'] ?? null;
$lng = $_POST['spawn_longitude'] ?? $_POST['longitude'] ?? $_POST['lng'] ?? null;
$radius = $_POST['spawn_radius_meters'] ?? $_POST['spawn_radius'] ?? $_POST['radius'] ?? null;
$pictureUrl = trim($_POST['picture_url'] ?? $_POST['image_url'] ?? $_POST['imageUrl'] ?? '');

if ($name === '' || $type === '' || $lat === null || $lng === null || $radius === null) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Missing required fields."]);
    exit;
}

$lat = floatval($lat);
$lng = floatval($lng);
$radius = floatval($radius);
$pictureUrl = $pictureUrl === '' ? null : $pictureUrl;

$stmt = $conn->prepare(
    'INSERT INTO monsterstbl (monster_name, monster_type, spawn_latitude, spawn_longitude, spawn_radius_meters, picture_url) VALUES (?, ?, ?, ?, ?, ?)'
);

if (!$stmt) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Prepare failed."]);
    exit;
}

// s s d d d s
$stmt->bind_param('ssddds', $name, $type, $lat, $lng, $radius, $pictureUrl);

if (!$stmt->execute()) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Insert failed."]);
    $stmt->close();
    $conn->close();
    exit;
}

$insertId = $stmt->insert_id;
$stmt->close();
$conn->close();

echo json_encode([
    "success" => true,
    "message" => "Monster created.",
    "monster_id" => $insertId,
]);