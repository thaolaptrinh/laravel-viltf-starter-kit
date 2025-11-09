<?php

declare(strict_types=1);

namespace App\Actions;

use App\Data\PasswordData;
use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

final readonly class UpdateUserPassword
{
    public function handle(User $user, PasswordData $data): void
    {
        if (! Hash::check($data->current_password, $user->password)) {
            throw ValidationException::withMessages([
                'current_password' => [__('The provided password does not match our records.')],
            ]);
        }

        $user->forceFill([
            'password' => $data->password,
        ])->save();
    }
}
