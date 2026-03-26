<?php
require __DIR__ . '/cors.php';
$conn = require __DIR__ . '/db.php';

// Get the player ID from the app
$player_id = $_POST['player_id'] ?? $_GET['player_id'] ?? null;

if ($player_id === null) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Missing player_id."]);
    exit;
}

$player_id = intval($player_id);

// Join the catch table and the monster table together
$sql = "SELECT c.catch_id, m.monster_id, m.monster_name, m.monster_type, m.picture_url
        FROM monster_catchestbl c
        JOIN monsterstbl m ON c.monster_id = m.monster_id
        WHERE c.player_id = ?";

$stmt = $conn->prepare($sql);

if (!$stmt) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Database prepare failed."]);
    exit;
}

$stmt->bind_param('i', $player_id);
$stmt->execute();
$result = $stmt->get_result();

$inventory = [];
if ($result && $result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        $inventory[] = [
            "catch_id" => (int)$row['catch_id'],
            "monster_id" => (int)$row['monster_id'],
            "monster_name" => $row['monster_name'],
            "monster_type" => $row['monster_type'],
            "picture_url" => $row['picture_url']
        ];
    }
}

// Return the list (it will be an empty list [] if they haven't caught anything yet)
echo json_encode(["success" => true, "data" => $inventory]);

$stmt->close();
$conn->close();
?>