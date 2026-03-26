<?php
require __DIR__ . '/cors.php';
$conn = require __DIR__ . '/db.php';

function pick_column(array $available, array $candidates) {
    foreach ($candidates as $candidate) {
        if (in_array($candidate, $available, true)) {
            return $candidate;
        }
    }
    return null;
}

function pick_column_contains(array $available, array $needles) {
    foreach ($available as $column) {
        $lower = strtolower($column);
        $ok = true;
        foreach ($needles as $needle) {
            if (strpos($lower, strtolower($needle)) === false) {
                $ok = false;
                break;
            }
        }
        if ($ok) {
            return $column;
        }
    }
    return null;
}

// 1. Get the GPS data sent from the Flutter App (matching your partner's input style)
$player_id = $_POST['player_id'] ?? 1; // Default to 1 for testing if not sent
$lat = $_POST['latitude'] ?? $_POST['lat'] ?? null;
$lng = $_POST['longitude'] ?? $_POST['lng'] ?? null;
$selected_monster_id = $_POST['monster_id'] ?? null;
$requested_location_id = $_POST['location_id'] ?? null;
$location_id = null;
$location_name = null;

$location_id_col = null;
$location_name_col = null;
$location_lat_col = null;
$location_lng_col = null;
$monster_location_col = null;

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
if ($requested_location_id !== null) {
    $requested_location_id = intval($requested_location_id);
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

// 1.55 Detect if monsterstbl has a location mapping column.
$monster_columns_result = $conn->query("SHOW COLUMNS FROM monsterstbl");
if ($monster_columns_result) {
    $monster_columns = [];
    while ($col = $monster_columns_result->fetch_assoc()) {
        if (isset($col['Field'])) {
            $monster_columns[] = $col['Field'];
        }
    }

    $monster_location_col = pick_column(
        $monster_columns,
        ['location_id', 'spawn_location_id', 'monster_location_id', 'locationid']
    );
}

// 1.6 Resolve location from locationstbl so catches are truly linked to location records.
$location_columns_result = $conn->query("SHOW COLUMNS FROM locationstbl");
if ($location_columns_result) {
    $available_columns = [];
    while ($col = $location_columns_result->fetch_assoc()) {
        if (isset($col['Field'])) {
            $available_columns[] = $col['Field'];
        }
    }

    $location_id_col = pick_column($available_columns, ['location_id', 'id', 'loc_id']);
    $location_name_col = pick_column($available_columns, ['location_name', 'name', 'location']);
    $location_lat_col = pick_column($available_columns, [
        'latitude', 'lat', 'location_latitude', 'center_latitude', 'location_lat', 'coord_lat'
    ]);
    $location_lng_col = pick_column($available_columns, [
        'longitude', 'lng', 'lon', 'location_longitude', 'center_longitude', 'location_lng', 'location_lon', 'coord_lng', 'coord_lon'
    ]);

    // Generic fallback if exact candidate names are different.
    if ($location_lat_col === null) {
        $location_lat_col = pick_column_contains($available_columns, ['lat']);
    }
    if ($location_lng_col === null) {
        $location_lng_col = pick_column_contains($available_columns, ['lng'])
            ?? pick_column_contains($available_columns, ['lon'])
            ?? pick_column_contains($available_columns, ['long']);
    }

    if ($location_id_col !== null) {
        if ($requested_location_id !== null && $requested_location_id > 0) {
            $select_name = $location_name_col !== null
                ? "`$location_name_col` AS location_name"
                : "CAST(`$location_id_col` AS CHAR) AS location_name";
            $sql_location_by_id = "SELECT `$location_id_col` AS location_id, $select_name FROM locationstbl WHERE `$location_id_col` = ? LIMIT 1";
            $loc_stmt = $conn->prepare($sql_location_by_id);
            if ($loc_stmt) {
                $loc_stmt->bind_param('i', $requested_location_id);
                $loc_stmt->execute();
                $loc_res = $loc_stmt->get_result();
                if ($loc_res && $loc_res->num_rows > 0) {
                    $loc_row = $loc_res->fetch_assoc();
                    $location_id = intval($loc_row['location_id']);
                    $location_name = $loc_row['location_name'] ?? null;
                }
                $loc_stmt->close();
            }
        }

        // If no valid requested location, pick nearest location to current player GPS.
        if ($location_id === null && $location_lat_col !== null && $location_lng_col !== null) {
            $select_name = $location_name_col !== null
                ? "`$location_name_col` AS location_name"
                : "CAST(`$location_id_col` AS CHAR) AS location_name";

            $sql_nearest_location = "SELECT
                    `$location_id_col` AS location_id,
                    $select_name,
                    (6371000 * acos(
                        cos(radians(?)) * cos(radians(`$location_lat_col`)) * cos(radians(`$location_lng_col`) - radians(?)) +
                        sin(radians(?)) * sin(radians(`$location_lat_col`))
                    )) AS distance
                FROM locationstbl
                ORDER BY distance ASC
                LIMIT 1";

            $loc_stmt = $conn->prepare($sql_nearest_location);
            if ($loc_stmt) {
                $loc_stmt->bind_param('ddd', $lat, $lng, $lat);
                $loc_stmt->execute();
                $loc_res = $loc_stmt->get_result();
                if ($loc_res && $loc_res->num_rows > 0) {
                    $loc_row = $loc_res->fetch_assoc();
                    $location_id = intval($loc_row['location_id']);
                    $location_name = $loc_row['location_name'] ?? null;
                }
                $loc_stmt->close();
            }
        }

        // Final fallback: if we still don't have a location_id, use the first
        // available location row to satisfy schemas where location_id is required.
        if ($location_id === null) {
            $select_name = $location_name_col !== null
                ? "`$location_name_col` AS location_name"
                : "CAST(`$location_id_col` AS CHAR) AS location_name";
            $sql_any_location = "SELECT `$location_id_col` AS location_id, $select_name FROM locationstbl ORDER BY `$location_id_col` ASC LIMIT 1";
            $loc_stmt = $conn->prepare($sql_any_location);
            if ($loc_stmt) {
                $loc_stmt->execute();
                $loc_res = $loc_stmt->get_result();
                if ($loc_res && $loc_res->num_rows > 0) {
                    $loc_row = $loc_res->fetch_assoc();
                    $location_id = intval($loc_row['location_id']);
                    $location_name = $loc_row['location_name'] ?? $location_name;
                }
                $loc_stmt->close();
            }
        }
    }
}

// 2. THE HAVERSINE FORMULA (Using Prepared Statements for security)
$monster_location_select = $monster_location_col !== null
    ? ", `$monster_location_col` AS monster_location_id"
    : "";

if ($selected_monster_id !== null) {
    // User selected a specific monster from the detected list.
    // Validate the selected monster is still in range before inserting catch.
    $sql = "SELECT monster_id, monster_name, spawn_radius_meters, spawn_latitude, spawn_longitude$monster_location_select,
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
    $sql = "SELECT monster_id, monster_name, spawn_radius_meters, spawn_latitude, spawn_longitude$monster_location_select,
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
    $monster_spawn_lat = isset($row['spawn_latitude']) ? floatval($row['spawn_latitude']) : $lat;
    $monster_spawn_lng = isset($row['spawn_longitude']) ? floatval($row['spawn_longitude']) : $lng;

    // Prefer explicit monster -> location mapping when available.
    if (isset($row['monster_location_id']) && intval($row['monster_location_id']) > 0) {
        $candidate_location_id = intval($row['monster_location_id']);
        if ($location_id_col !== null) {
            $select_name = $location_name_col !== null
                ? "`$location_name_col` AS location_name"
                : "CAST(`$location_id_col` AS CHAR) AS location_name";
            $sql_loc_from_monster = "SELECT `$location_id_col` AS location_id, $select_name FROM locationstbl WHERE `$location_id_col` = ? LIMIT 1";
            $loc_from_monster_stmt = $conn->prepare($sql_loc_from_monster);
            if ($loc_from_monster_stmt) {
                $loc_from_monster_stmt->bind_param('i', $candidate_location_id);
                $loc_from_monster_stmt->execute();
                $loc_from_monster_res = $loc_from_monster_stmt->get_result();
                if ($loc_from_monster_res && $loc_from_monster_res->num_rows > 0) {
                    $loc_from_monster = $loc_from_monster_res->fetch_assoc();
                    $location_id = intval($loc_from_monster['location_id']);
                    $location_name = $loc_from_monster['location_name'] ?? $location_name;
                } else {
                    $location_id = $candidate_location_id;
                }
                $loc_from_monster_stmt->close();
            }
        } else {
            $location_id = $candidate_location_id;
        }
    }

    // If monster table has no explicit location mapping, map location from monster spawn point.
    if ($location_id_col !== null && $location_lat_col !== null && $location_lng_col !== null) {
        if (!(isset($row['monster_location_id']) && intval($row['monster_location_id']) > 0)) {
            $select_name = $location_name_col !== null
                ? "`$location_name_col` AS location_name"
                : "CAST(`$location_id_col` AS CHAR) AS location_name";

            $sql_nearest_to_monster = "SELECT
                    `$location_id_col` AS location_id,
                    $select_name,
                    (6371000 * acos(
                        cos(radians(?)) * cos(radians(`$location_lat_col`)) * cos(radians(`$location_lng_col`) - radians(?)) +
                        sin(radians(?)) * sin(radians(`$location_lat_col`))
                    )) AS distance
                FROM locationstbl
                ORDER BY distance ASC
                LIMIT 1";

            $loc_from_spawn_stmt = $conn->prepare($sql_nearest_to_monster);
            if ($loc_from_spawn_stmt) {
                $loc_from_spawn_stmt->bind_param('ddd', $monster_spawn_lat, $monster_spawn_lng, $monster_spawn_lat);
                $loc_from_spawn_stmt->execute();
                $loc_from_spawn_res = $loc_from_spawn_stmt->get_result();
                if ($loc_from_spawn_res && $loc_from_spawn_res->num_rows > 0) {
                    $loc_from_spawn = $loc_from_spawn_res->fetch_assoc();
                    $location_id = intval($loc_from_spawn['location_id']);
                    $location_name = $loc_from_spawn['location_name'] ?? $location_name;
                }
                $loc_from_spawn_stmt->close();
            }
        }
    }

    $stmt->close();
    
    // 4. Save the catch into the database using a Prepared Statement.
    // Try with location_id first. If DB schema differs, fallback without location_id.
    $insert_sql_with_location = "INSERT INTO monster_catchestbl (player_id, monster_id, location_id, latitude, longitude) VALUES (?, ?, ?, ?, ?)";
    $insert_sql_no_location = "INSERT INTO monster_catchestbl (player_id, monster_id, latitude, longitude) VALUES (?, ?, ?, ?)";

    $insert_stmt = null;
    $used_location = false;

    if ($location_id !== null) {
        $insert_stmt = $conn->prepare($insert_sql_with_location);
        $used_location = ($insert_stmt !== false && $insert_stmt !== null);
    }

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
            "catch_id" => $conn->insert_id,
            "location_id" => $location_id,
            "location_name" => $location_name
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