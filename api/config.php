<?php
// Keep secrets out of source control when possible.
// Prefer setting these as environment variables on the web server.

return [
    'db_host' => getenv('DB_HOST') ?: '10.2.1.15',
    'db_user' => getenv('DB_USER') ?: 'api_user',
    'db_pass' => getenv('DB_PASS') ?: 'PokemonPassword123!',
    'db_name' => getenv('DB_NAME') ?: 'haumonstersDB',
];