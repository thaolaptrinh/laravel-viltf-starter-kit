<?php

declare(strict_types=1);

use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

test('login page can be rendered', function (): void {
    $response = $this->get(route('filament.admin.auth.login'));

    $response->assertOk();
});
