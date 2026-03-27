<?php
require __DIR__ . '/cors.php';
$conn = require __DIR__ . '/db.php';

$sql = "SELECT player_id, player_name, username FROM playerstbl ORDER BY player_id ASC";
$result = $conn->query($sql);

if (!$result) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "Failed to load players."
    ]);
    $conn->close();
    exit;
}

$players = [];
while ($row = $result->fetch_assoc()) {
    $players[] = [
        "player_id" => (int)$row['player_id'],
        "player_name" => $row['player_name'],
        "username" => $row['username'],
    ];
}

echo json_encode([
    "success" => true,
    "data" => $players,
]);

$conn->close();
?>
