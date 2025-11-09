<?php

declare(strict_types=1);

namespace App\Data;

use Spatie\LaravelData\Data;

final class WelcomeData extends Data
{
    public function __construct(
        public bool $canRegister,
    ) {}
}
