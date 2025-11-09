<?php

declare(strict_types=1);

namespace App\Actions;

use App\Data\ProfileData;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final readonly class UpdateUserProfile
{
    public function handle(User $user, ProfileData $data): User
    {
        ProfileData::validate($data->toArray());

        if (User::query()->where('email', $data->email)->where('id', '!=', $user->id)->exists()) {
            throw ValidationException::withMessages([
                'email' => [__('validation.unique', ['attribute' => 'email'])],
            ]);
        }

        $emailChanged = $data->email !== $user->email;

        DB::transaction(function () use ($user, $data, $emailChanged): void {
            $user->forceFill([
                'name' => $data->name,
                'email' => $data->email,
                ...($emailChanged ? ['email_verified_at' => null] : []),
            ])->save();
        });

        return $user->fresh();
    }
}
