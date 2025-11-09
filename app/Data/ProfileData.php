<?php

declare(strict_types=1);

namespace App\Data;

use Spatie\LaravelData\Attributes\Validation\Email;
use Spatie\LaravelData\Attributes\Validation\Max;
use Spatie\LaravelData\Attributes\Validation\Required;
use Spatie\LaravelData\Attributes\Validation\StringType;
use Spatie\LaravelData\Data;

final class ProfileData extends Data
{
    public function __construct(
        #[Required, StringType, Max(255)]
        public string $name,
        #[Required, StringType, Email, Max(255)]
        public string $email,
    ) {}
}
