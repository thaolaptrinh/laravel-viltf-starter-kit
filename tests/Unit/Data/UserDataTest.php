<?php

declare(strict_types=1);

use App\Data\UserData;
use App\Models\User;

test('user data can be created from user model', function (): void {
    $user = User::factory()->create();

    $data = UserData::fromUser($user);

    expect($data)
        ->id->toBe($user->id)
        ->name->toBe($user->name)
        ->email->toBe($user->email);
});

test('user data formats dates as ISO strings', function (): void {
    $user = User::factory()->create();

    $data = UserData::fromUser($user);

    expect($data->created_at)->toBe($user->created_at->toISOString())
        ->and($data->updated_at)->toBe($user->updated_at->toISOString());
});

test('user data maps verified email to iso string', function (): void {
    $user = User::factory()->create();

    $data = UserData::fromUser($user);

    expect($data->email_verified_at)->toBe($user->email_verified_at->toISOString());
});

test('user data sets null when email is not verified', function (): void {
    $user = User::factory()->unverified()->create();

    $data = UserData::fromUser($user);

    expect($data->email_verified_at)->toBeNull();
});
