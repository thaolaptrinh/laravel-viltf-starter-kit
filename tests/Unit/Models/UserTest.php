<?php

declare(strict_types=1);

use App\Models\User;

test('user can be created', function (): void {
    $user = User::factory()->create();

    expect($user)->toBeInstanceOf(User::class);
    expect($user->exists)->toBeTrue();
});

test('user has expected fillable attributes', function (): void {
    $user = new User;

    expect($user->getFillable())->toBe(['name', 'email', 'password']);
});

test('password is cast as hashed', function (): void {
    $user = User::factory()->create();

    expect($user->password)->not->toBe('password');
    expect(Illuminate\Support\Facades\Hash::check('password', $user->password))->toBeTrue();
});

test('email verification can be toggled', function (): void {
    $verifiedUser = User::factory()->create();
    $unverifiedUser = User::factory()->unverified()->create();

    expect($verifiedUser->email_verified_at)->not->toBeNull();
    expect($unverifiedUser->email_verified_at)->toBeNull();
});

test('two factor authentication can be disabled', function (): void {
    $user = User::factory()->withoutTwoFactor()->create();

    expect($user->two_factor_secret)->toBeNull();
    expect($user->two_factor_recovery_codes)->toBeNull();
    expect($user->two_factor_confirmed_at)->toBeNull();
});
