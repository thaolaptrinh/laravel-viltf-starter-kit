<?php

declare(strict_types=1);

namespace App\Data;

use App\Models\User;
use Spatie\LaravelData\Data;

final class UserData extends Data
{
    public function __construct(
        public int $id,
        public string $name,
        public string $email,
        public ?string $avatar,
        public ?string $email_verified_at,
        public string $created_at,
        public string $updated_at,
    ) {}

    public static function fromUser(User $user): self
    {
        return new self(
            id: $user->id,
            name: $user->name,
            email: $user->email,
            avatar: $user->avatar,
            email_verified_at: $user->email_verified_at?->toISOString(),
            created_at: $user->created_at->toISOString(),
            updated_at: $user->updated_at->toISOString(),
        );
    }
}
