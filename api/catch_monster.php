<?php
require __DIR__ . '/cors.php';
$conn = require __DIR__ . '/db.php';

// 1. Get the GPS data sent from the Flutter App (matching your partner's input style)
$player_id = $_POST['player_id'] ?? 1; // Default to 1 for testing if not sent
$lat = $_POST['latitude'] ?? $_POST['lat'] ?? null;
$lng = $_POST['longitude'] ?? $_POST['lng'] ?? null;
$selected_monster_id = $_POST['monster_id'] ?? null;
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

if ($selected_monster_id !== null) {
    $selected_monster_id = intval($selected_monster_id);
}

// 1.5 Ensure player exists to avoid FK insert failures.
$player_check = $conn->prepare("SELECT player_id FROM playerstbl WHERE player_id = ? LIMIT 1");
if (!$player_check) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => "Prepare failed for player validation: " . $conn->error]);
    exit;
}
$player_check->bind_param('i', $player_id);
$player_check->execute();
$player_result = $player_check->get_result();
if (!$player_result || $player_result->num_rows === 0) {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "message" => "Invalid player_id. Please login again.",
        "player_id" => $player_id
    ]);
    $player_check->close();
    $conn->close();
    exit;
}
$player_check->close();

// 2. THE HAVERSINE FORMULA (Using Prepared Statements for security)
if ($selected_monster_id !== null) {
    // User selected a specific monster from the detected list.
    // Validate the selected monster is still in range before inserting catch.
    $sql = "SELECT monster_id, monster_name, spawn_radius_meters,
            (6371000 * acos(
                cos(radians(?)) * cos(radians(spawn_latitude)) * cos(radians(spawn_longitude) - radians(?)) +
                sin(radians(?)) * sin(radians(spawn_latitude))
            )) AS distance
            FROM monsterstbl
            WHERE monster_id = ?
            HAVING distance <= spawn_radius_meters
            LIMIT 1";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        http_response_code(500);
        echo json_encode(["success" => false, "message" => "Prepare failed for selected monster check: " . $conn->error]);
        exit;
    }

    $stmt->bind_param('dddi', $lat, $lng, $lat, $selected_monster_id);
} else {
    // Fallback: closest in-range monster.
    $sql = "SELECT monster_id, monster_name, spawn_radius_meters,
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
        echo json_encode(["success" => false, "message" => "Prepare failed for distance calculation: " . $conn->error]);
        exit;
    }

    // Bind the latitude and longitude into the formula (d = double/float)
    $stmt->bind_param('ddd', $lat, $lng, $lat);
}

$stmt->execute();
$result = $stmt->get_result();

// 3. Check if a monster was close enough
if ($result && $result->num_rows > 0) {
    $row = $result->fetch_assoc();
    $monster_id = $row['monster_id'];
    $monster_name = $row['monster_name'];
    $stmt->close();
    
    // 4. Save the catch into the database using a Prepared Statement.
    // Try with location_id first. If DB schema differs, fallback without location_id.
    $insert_sql_with_location = "INSERT INTO monster_catchestbl (player_id, monster_id, location_id, latitude, longitude) VALUES (?, ?, ?, ?, ?)";
    $insert_sql_no_location = "INSERT INTO monster_catchestbl (player_id, monster_id, latitude, longitude) VALUES (?, ?, ?, ?)";

    $insert_stmt = $conn->prepare($insert_sql_with_location);
    $used_location = true;

    if (!$insert_stmt) {
        $insert_stmt = $conn->prepare($insert_sql_no_location);
        $used_location = false;
    }

    if (!$insert_stmt) {
        http_response_code(500);
        echo json_encode(["success" => false, "message" => "Prepare failed for catching: " . $conn->error]);
        $conn->close();
        exit;
    }

    if ($used_location) {
        $insert_stmt->bind_param('iiidd', $player_id, $monster_id, $location_id, $lat, $lng);
    } else {
        $insert_stmt->bind_param('iidd', $player_id, $monster_id, $lat, $lng);
    }

    $ok = $insert_stmt->execute();

    // If location_id path failed (common FK issue), retry without location_id.
    if (!$ok && $used_location) {
        $insert_error = $insert_stmt->error;
        $insert_stmt->close();

        $insert_stmt = $conn->prepare($insert_sql_no_location);
        if ($insert_stmt) {
            $insert_stmt->bind_param('iidd', $player_id, $monster_id, $lat, $lng);
            $ok = $insert_stmt->execute();
        } else {
            $ok = false;
            $insert_error = $insert_error . ' | fallback prepare: ' . $conn->error;
        }

        if (!$ok) {
            http_response_code(500);
            echo json_encode([
                "success" => false,
                "message" => "Insert failed during catch: " . ($insert_stmt ? $insert_stmt->error : $insert_error)
            ]);
            if ($insert_stmt) $insert_stmt->close();
            $conn->close();
            exit;
        }
    }

    if ($ok) {
        echo json_encode([
            "success" => true,
            "monster_name" => $monster_name,
            "message" => "You caught a $monster_name!",
            "catch_id" => $conn->insert_id
        ]);
    } else {
        http_response_code(500);
        echo json_encode(["success" => false, "message" => "Insert failed during catch: " . $insert_stmt->error]);
    }

    $insert_stmt->close();
} else {
    // Player is too far away from any spawn points
    if ($selected_monster_id !== null) {
        echo json_encode(["success" => false, "message" => "Selected monster is out of range or not found."]);
    } else {
        echo json_encode(["success" => false, "message" => "No monsters nearby! Keep walking."]);
    }
    $stmt->close();
}

$conn->close();
?>