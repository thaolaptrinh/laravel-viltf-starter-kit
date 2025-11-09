<?php

declare(strict_types=1);

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Inertia\Testing\AssertableInertia;
use Inertia\Testing\AssertableInertia as Assert;

uses(RefreshDatabase::class);

test('confirm password screen can be rendered', function (): void {
    $user = User::factory()->create();

    $response = $this->actingAs($user)->get(route('password.confirm'));

    $response->assertStatus(200);

    $response->assertInertia(fn (Assert $page): AssertableInertia => $page
        ->component('auth/ConfirmPassword')
    );
});

test('password confirmation requires authentication', function (): void {
    $response = $this->get(route('password.confirm'));

    $response->assertRedirect(route('login'));
});
