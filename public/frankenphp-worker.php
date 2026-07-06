<?php

declare(strict_types=1);

use Illuminate\Http\Request;

define('LARAVEL_START', microtime(true));

if (file_exists($maintenance = __DIR__.'/../storage/framework/maintenance.php')) {
    require $maintenance;
}

require __DIR__.'/../vendor/autoload.php';

$app = require __DIR__.'/../bootstrap/app.php';

$app->handleRequest(Request::capture())->send();

// frankenphp_handle_request() is called by the runtime after worker boot loop.
// This file is the entry point for FrankenPHP worker mode (Octane).
// See: https://frankenphp.dev/docs/worker/
