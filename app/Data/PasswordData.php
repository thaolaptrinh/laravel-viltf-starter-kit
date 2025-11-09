<?php

declare(strict_types=1);

namespace App\Data;

use Spatie\LaravelData\Attributes\Validation\Confirmed;
use Spatie\LaravelData\Attributes\Validation\Min;
use Spatie\LaravelData\Attributes\Validation\Required;
use Spatie\LaravelData\Attributes\Validation\StringType;
use Spatie\LaravelData\Data;

final class PasswordData extends Data
{
    public function __construct(
        #[Required, StringType]
        public string $current_password,
        #[Required, StringType, Confirmed, Min(8)]
        public string $password,
    ) {}
}
