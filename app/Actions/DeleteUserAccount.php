<?php

declare(strict_types=1);

namespace App\Actions;

use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

final class DeleteUserAccount
{
    public function handle(User $user, string $password): void
    {
        if (! Hash::check($password, $user->password)) {
            throw ValidationException::withMessages([
                'password' => [__('The provided password does not match our records.')],
            ]);
        }

        $user->delete();
    }
}
