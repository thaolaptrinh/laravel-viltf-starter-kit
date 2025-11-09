<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Filament Panels
    |--------------------------------------------------------------------------
    |
    | Here you may configure your Filament panels. Each panel represents a
    | separate area of your application that uses Filament. You can have as
    | many panels as you like, and each will be completely independent.
    |
    */

    'panels' => [
        'admin' => [
            'id' => 'admin',
            'domain' => env('FILAMENT_ADMIN_DOMAIN', 'localhost'),
            'path' => env('FILAMENT_ADMIN_PATH', 'admin'),
            'spa' => env('FILAMENT_ADMIN_SPA', false),
        ],
    ],
];
