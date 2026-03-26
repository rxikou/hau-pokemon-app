<?php
require __DIR__ . '/cors.php';
$conn = require __DIR__ . '/db.php';

// SQL query to count how many monsters each player has caught
$sql = "SELECT p.player_id, p.player_name, COUNT(c.catch_id) as total_catches 
        FROM playerstbl p
        LEFT JOIN monster_catchestbl c ON p.player_id = c.player_id
        GROUP BY p.player_id, p.player_name
        ORDER BY total_catches DESC";

$result = $conn->query($sql);

$leaderboard = [];
if ($result && $result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        $leaderboard[] = [
            "player_id" => (int)$row['player_id'],
            "player_name" => $row['player_name'],
            "total_catches" => (int)$row['total_catches']
        ];
    }
}

echo json_encode(["success" => true, "data" => $leaderboard]);
$conn->close();
?>