<?php

declare(strict_types=1);

test('type script transformer config is properly configured', function (): void {
    $config = resolve(Spatie\TypeScriptTransformer\TypeScriptTransformerConfig::class);

    expect($config->outputDirectory)->toBe(resource_path('js/types/generated'));
});

test('type script transformer uses module writer', function (): void {
    $config = resolve(Spatie\TypeScriptTransformer\TypeScriptTransformerConfig::class);

    expect($config->typesWriter)->toBeInstanceOf(
        Spatie\TypeScriptTransformer\Writers\ModuleWriter::class,
    );
});

test('type script transformer includes data directory', function (): void {
    $config = resolve(Spatie\TypeScriptTransformer\TypeScriptTransformerConfig::class);

    expect($config->directoriesToWatch)->toContain(app_path('Data'));
});

test('type script transformer includes laravel data extension', function (): void {
    $config = resolve(Spatie\TypeScriptTransformer\TypeScriptTransformerConfig::class);

    expect($config->transformedProviders)->not->toBeEmpty();
});
