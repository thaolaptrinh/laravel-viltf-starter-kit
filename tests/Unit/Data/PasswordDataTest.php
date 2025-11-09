<?php

declare(strict_types=1);

use App\Data\PasswordData;

test('password data can be created with valid data', function (): void {
    $data = new PasswordData(
        current_password: 'current-pass',
        password: 'new-password',
    );

    expect($data)
        ->current_password->toBe('current-pass')
        ->password->toBe('new-password');
});

test('password data validates required fields', function (): void {
    PasswordData::validate([
        'current_password' => '',
        'password' => '',
    ]);
})->throws(Illuminate\Validation\ValidationException::class);

test('password data validates confirmation', function (): void {
    PasswordData::validate([
        'current_password' => 'current-pass',
        'password' => 'new-password',
        'password_confirmation' => 'different-password',
    ]);
})->throws(Illuminate\Validation\ValidationException::class);

test('password data validates minimum length', function (): void {
    PasswordData::validate([
        'current_password' => 'current-pass',
        'password' => 'short',
        'password_confirmation' => 'short',
    ]);
})->throws(Illuminate\Validation\ValidationException::class);
