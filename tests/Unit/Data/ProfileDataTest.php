<?php

declare(strict_types=1);

use App\Data\ProfileData;

test('profile data can be created with valid data', function (): void {
    $data = new ProfileData(
        name: 'John Doe',
        email: 'john@example.com',
    );

    expect($data)
        ->name->toBe('John Doe')
        ->email->toBe('john@example.com');
});

test('profile data validates required fields', function (): void {
    ProfileData::validate([
        'name' => '',
        'email' => '',
    ]);
})->throws(Illuminate\Validation\ValidationException::class);

test('profile data validates email format', function (): void {
    ProfileData::validate([
        'name' => 'John',
        'email' => 'not-an-email',
    ]);
})->throws(Illuminate\Validation\ValidationException::class);

test('profile data validates max length', function (): void {
    ProfileData::validate([
        'name' => str_repeat('a', 256),
        'email' => 'john@example.com',
    ]);
})->throws(Illuminate\Validation\ValidationException::class);
