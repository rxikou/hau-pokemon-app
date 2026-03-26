<?php
require __DIR__ . '/cors.php';
$conn = require __DIR__ . '/db.php';

$sql = 'SELECT monster_id, monster_name, monster_type, spawn_latitude, spawn_longitude, spawn_radius_meters, picture_url FROM monsterstbl';
$result = $conn->query($sql);

$monsters = [];
if ($result && $result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        $monsters[] = $row;
    }
}

echo json_encode(["success" => true, "data" => $monsters]);
$conn->close();