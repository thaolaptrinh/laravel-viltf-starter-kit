<?php

declare(strict_types=1);

namespace App\Providers;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
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
        Model::preventLazyLoading(! app()->isProduction());
        $this->bootLoadMigrations();
        $this->bootModelsDefaults();
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

    /**
     * Boot the models defaults.
     */
    private function bootModelsDefaults(): void
    {
        Model::unguard();
    }
}
