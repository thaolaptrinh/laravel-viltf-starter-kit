<?php

declare(strict_types=1);

use App\Actions\UpdateUserPassword;
use App\Data\PasswordData;
use App\Models\User;
use Illuminate\Support\Facades\Hash;

test('user can update their password', function (): void {
    $user = User::factory()->create();

    $data = new PasswordData(
        current_password: 'password',
        password: 'new-password',
    );

    app(UpdateUserPassword::class)->handle($user, $data);

    expect(Hash::check('new-password', $user->fresh()->password))->toBeTrue();
});

test('current password must be correct to update password', function (): void {
    $user = User::factory()->create();

    $data = new PasswordData(
        current_password: 'wrong-password',
        password: 'new-password',
    );

    app(UpdateUserPassword::class)->handle($user, $data);
})->throws(Illuminate\Validation\ValidationException::class, 'The provided password does not match our records.');
