<?php

declare(strict_types=1);

namespace App\Providers;

use Illuminate\Support\Facades\URL;
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

        // Force HTTPS scheme when behind Traefik in staging/production.
        // Trusted proxies are configured via bootstrap/app.php middleware.
        if ($this->app->environment('production', 'staging')) {
            URL::forceScheme('https');
        }
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
