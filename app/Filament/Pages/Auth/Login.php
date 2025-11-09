<?php

declare(strict_types=1);

namespace App\Filament\Pages\Auth;

use Filament\Auth\Pages\Login as BasePage;

final class Login extends BasePage
{
    public function mount(): void
    {
        parent::mount();

        if (! app()->isProduction()) {
            $this->form->fill([
                'email' => 'admin@example.com',
                'password' => 'password',
                'remember' => true,
            ]);
        }
    }
}
