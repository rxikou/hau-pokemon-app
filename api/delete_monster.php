<?php
require __DIR__ . '/cors.php';
$conn = require __DIR__ . '/db.php';

$id = $_POST['monster_id'] ?? $_POST['id'] ?? null;
if ($id === null) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Missing monster_id."]);
    exit;
}

$id = intval($id);

$stmt = $conn->prepare('DELETE FROM monsterstbl WHERE monster_id = ?');
if (!$stmt) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Prepare failed."]);
    exit;
}

$stmt->bind_param('i', $id);

if (!$stmt->execute()) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Delete failed."]);
    $stmt->close();
    $conn->close();
    exit;
}

$affected = $stmt->affected_rows;
$stmt->close();
$conn->close();

echo json_encode([
    "success" => true,
    "message" => $affected > 0 ? "Monster deleted." : "Monster not found.",
    "affected_rows" => $affected,
]);