<?php
require __DIR__ . '/cors.php';
$conn = require __DIR__ . '/db.php';

$player_id = intval($_POST['player_id'] ?? $_GET['player_id'] ?? 0);

if ($player_id <= 0) {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "message" => "Missing or invalid player_id."
    ]);
    $conn->close();
    exit;
}

$exists_stmt = $conn->prepare("SELECT player_id FROM playerstbl WHERE player_id = ? LIMIT 1");
if (!$exists_stmt) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => "Database prepare failed."
    ]);
    $conn->close();
    exit;
}

$exists_stmt->bind_param('i', $player_id);
$exists_stmt->execute();
$exists_res = $exists_stmt->get_result();
if (!$exists_res || $exists_res->num_rows === 0) {
    http_response_code(404);
    echo json_encode([
        "success" => false,
        "message" => "Player not found."
    ]);
    $exists_stmt->close();
    $conn->close();
    exit;
}
$exists_stmt->close();

$conn->begin_transaction();

try {
    // Delete dependent catches first for schemas without ON DELETE CASCADE.
    $delete_catches_stmt = $conn->prepare("DELETE FROM monster_catchestbl WHERE player_id = ?");
    if (!$delete_catches_stmt) {
        throw new Exception('Database prepare failed.');
    }
    $delete_catches_stmt->bind_param('i', $player_id);
    $delete_catches_stmt->execute();
    $delete_catches_stmt->close();

    $delete_player_stmt = $conn->prepare("DELETE FROM playerstbl WHERE player_id = ?");
    if (!$delete_player_stmt) {
        throw new Exception('Database prepare failed.');
    }
    $delete_player_stmt->bind_param('i', $player_id);
    $delete_player_stmt->execute();
    $deleted = $delete_player_stmt->affected_rows;
    $delete_player_stmt->close();

    if ($deleted <= 0) {
        throw new Exception('Player not found.');
    }

    $conn->commit();

    echo json_encode([
        "success" => true,
        "message" => "Player deleted.",
        "player_id" => $player_id
    ]);
} catch (Exception $e) {
    $conn->rollback();

    http_response_code(500);
    echo json_encode([
        "success" => false,
        "message" => $e->getMessage() === 'Player not found.' ? 'Player not found.' : 'Delete failed.'
    ]);
}

$conn->close();
?>
