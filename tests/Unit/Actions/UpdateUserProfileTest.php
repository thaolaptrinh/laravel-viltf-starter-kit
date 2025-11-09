<?php

declare(strict_types=1);

use App\Actions\UpdateUserProfile;
use App\Data\ProfileData;
use App\Models\User;

test('user profile information can be updated', function (): void {
    $user = User::factory()->create();

    $data = new ProfileData(
        name: 'Test User',
        email: 'test@example.com',
    );

    app(UpdateUserProfile::class)->handle($user, $data);

    expect($user->fresh())
        ->name->toBe('Test User')
        ->email->toBe('test@example.com');
});

test('email verification status is reset when email changes', function (): void {
    $user = User::factory()->create(['email_verified_at' => now()]);

    $data = new ProfileData(
        name: $user->name,
        email: 'new-email@example.com',
    );

    app(UpdateUserProfile::class)->handle($user, $data);

    expect($user->fresh()->email_verified_at)->toBeNull();
});

test('email verification status is unchanged when email stays the same', function (): void {
    $user = User::factory()->create();

    $data = new ProfileData(
        name: 'Updated Name',
        email: $user->email,
    );

    app(UpdateUserProfile::class)->handle($user, $data);

    expect($user->fresh()->email_verified_at)->not->toBeNull();
});

test('email must be unique', function (): void {
    User::factory()->create(['email' => 'existing@example.com']);
    $user = User::factory()->create();

    $data = new ProfileData(
        name: $user->name,
        email: 'existing@example.com',
    );

    app(UpdateUserProfile::class)->handle($user, $data);
})->throws(Illuminate\Validation\ValidationException::class);
