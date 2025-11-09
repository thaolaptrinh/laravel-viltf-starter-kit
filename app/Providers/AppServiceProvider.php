<?php

declare(strict_types=1);

namespace App\Providers;

use Illuminate\Support\ServiceProvider;

final class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        $this->bootLoadMigrations();
    }

    /**
     * Boot load migrations
     */
    private function bootLoadMigrations(): void
    {
        //  Load migrations
        $migrationsPath = database_path('migrations');

        /** @var list<string> $directories */
        $directories = glob($migrationsPath.'/*', GLOB_ONLYDIR) ?: [];
        $path = array_merge([$migrationsPath], $directories);

        $this->loadMigrationsFrom($path);
    }
}
