<?php

declare(strict_types=1);

use App\Actions\DeleteUserAccount;
use App\Models\User;

test('user can delete their account', function (): void {
    $user = User::factory()->create();

    app(DeleteUserAccount::class)->handle($user, 'password');

    expect($user->fresh())->toBeNull();
});

test('correct password must be provided to delete account', function (): void {
    $user = User::factory()->create();

    app(DeleteUserAccount::class)->handle($user, 'wrong-password');
})->throws(Illuminate\Validation\ValidationException::class, 'The provided password does not match our records.');
