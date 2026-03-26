<?php
require __DIR__ . '/cors.php';
$conn = require __DIR__ . '/db.php';

// 1. Get the GPS data sent from the Flutter App (matching your partner's input style)
$player_id = $_POST['player_id'] ?? 1; // Default to 1 for testing if not sent
$lat = $_POST['latitude'] ?? $_POST['lat'] ?? null;
$lng = $_POST['longitude'] ?? $_POST['lng'] ?? null;
$location_id = 1; // Using the 'HAU Campus' location we created earlier

// Ensure we actually received GPS coordinates
if ($lat === null || $lng === null) {
    http_response_code(400);
    echo json_encode(["success" => false, "message" => "Missing latitude or longitude."]);
    exit;
}

$player_id = intval($player_id);
$lat = floatval($lat);
$lng = floatval($lng);

// 2. THE HAVERSINE FORMULA (Using Prepared Statements for security)
$sql = "SELECT monster_id, monster_name, 
        (6371000 * acos(
            cos(radians(?)) * cos(radians(spawn_latitude)) * cos(radians(spawn_longitude) - radians(?)) + 
            sin(radians(?)) * sin(radians(spawn_latitude))
        )) AS distance 
        FROM monsterstbl 
        HAVING distance <= spawn_radius_meters 
        ORDER BY distance ASC LIMIT 1";

$stmt = $conn->prepare($sql);
if (!$stmt) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Prepare failed for distance calculation."]);
    exit;
}

// Bind the latitude and longitude into the formula (d = double/float)
$stmt->bind_param('ddd', $lat, $lng, $lat);
$stmt->execute();
$result = $stmt->get_result();

// 3. Check if a monster was close enough
if ($result && $result->num_rows > 0) {
    $row = $result->fetch_assoc();
    $monster_id = $row['monster_id'];
    $monster_name = $row['monster_name'];
    $stmt->close();
    
    // 4. Save the catch into the database using a Prepared Statement
    $insert_stmt = $conn->prepare(
        "INSERT INTO monster_catchestbl (player_id, monster_id, location_id, latitude, longitude) VALUES (?, ?, ?, ?, ?)"
    );
    
    if (!$insert_stmt) {
        http_response_code(500);
        echo json_encode(["success" => false, "message" => "Prepare failed for catching."]);
        $conn->close();
        exit;
    }

    // Bind parameters: integer, integer, integer, double, double
    $insert_stmt->bind_param('iiidd', $player_id, $monster_id, $location_id, $lat, $lng);
    
    if ($insert_stmt->execute()) {
        echo json_encode([
            "success" => true, 
            "monster_name" => $monster_name, 
            "message" => "You caught a $monster_name!"
        ]);
    } else {
        http_response_code(500);
        echo json_encode(["success" => false, "message" => "Insert failed during catch."]);
    }
    
    $insert_stmt->close();
} else {
    // Player is too far away from any spawn points
    echo json_encode(["success" => false, "message" => "No monsters nearby! Keep walking."]);
    $stmt->close();
}

$conn->close();
?>