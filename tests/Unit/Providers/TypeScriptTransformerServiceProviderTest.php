<?php

declare(strict_types=1);

use App\Providers\TypeScriptTransformerServiceProvider;
use Spatie\LaravelData\LaravelData;

test('type script transformer config is properly configured', function (): void {
    $config = app(\Spatie\TypeScriptTransformer\TypeScriptTransformerConfig::class);

    expect($config->outputDirectory)->toBe(resource_path('js/types/generated'));
});

test('type script transformer uses module writer', function (): void {
    $config = app(\Spatie\TypeScriptTransformer\TypeScriptTransformerConfig::class);

    expect($config->typesWriter)->toBeInstanceOf(
        \Spatie\TypeScriptTransformer\Writers\ModuleWriter::class,
    );
});

test('type script transformer includes data directory', function (): void {
    $config = app(\Spatie\TypeScriptTransformer\TypeScriptTransformerConfig::class);

    expect($config->directoriesToWatch)->toContain(app_path('Data'));
});

test('type script transformer includes laravel data extension', function (): void {
    $config = app(\Spatie\TypeScriptTransformer\TypeScriptTransformerConfig::class);

    expect($config->transformedProviders)->not->toBeEmpty();
});
