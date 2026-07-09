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
        $createdAt = $user->created_at->toISOString();
        $updatedAt = $user->updated_at->toISOString();

        assert($createdAt !== null);
        assert($updatedAt !== null);

        return new self(
            id: $user->id,
            name: $user->name,
            email: $user->email,
            avatar: $user->avatar,
            email_verified_at: $user->email_verified_at?->toISOString(),
            created_at: $createdAt,
            updated_at: $updatedAt,
        );
    }
}
