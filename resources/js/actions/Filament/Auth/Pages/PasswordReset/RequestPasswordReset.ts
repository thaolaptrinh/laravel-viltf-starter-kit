import { queryParams, type RouteQueryOptions, type RouteDefinition, type RouteFormDefinition } from './../../../../../wayfinder'
/**
* @see \Filament\Auth\Pages\PasswordReset\RequestPasswordReset::__invoke
* @see vendor/filament/filament/src/Auth/Pages/PasswordReset/RequestPasswordReset.php:7
* @route 'https://localhost/admin/password-reset/request'
*/
const RequestPasswordReset = (options?: RouteQueryOptions): RouteDefinition<'get'> => ({
    url: RequestPasswordReset.url(options),
    method: 'get',
})

RequestPasswordReset.definition = {
    methods: ["get","head"],
    url: 'https://localhost/admin/password-reset/request',
} satisfies RouteDefinition<["get","head"]>

/**
* @see \Filament\Auth\Pages\PasswordReset\RequestPasswordReset::__invoke
* @see vendor/filament/filament/src/Auth/Pages/PasswordReset/RequestPasswordReset.php:7
* @route 'https://localhost/admin/password-reset/request'
*/
RequestPasswordReset.url = (options?: RouteQueryOptions) => {
    return RequestPasswordReset.definition.url + queryParams(options)
}

/**
* @see \Filament\Auth\Pages\PasswordReset\RequestPasswordReset::__invoke
* @see vendor/filament/filament/src/Auth/Pages/PasswordReset/RequestPasswordReset.php:7
* @route 'https://localhost/admin/password-reset/request'
*/
RequestPasswordReset.get = (options?: RouteQueryOptions): RouteDefinition<'get'> => ({
    url: RequestPasswordReset.url(options),
    method: 'get',
})

/**
* @see \Filament\Auth\Pages\PasswordReset\RequestPasswordReset::__invoke
* @see vendor/filament/filament/src/Auth/Pages/PasswordReset/RequestPasswordReset.php:7
* @route 'https://localhost/admin/password-reset/request'
*/
RequestPasswordReset.head = (options?: RouteQueryOptions): RouteDefinition<'head'> => ({
    url: RequestPasswordReset.url(options),
    method: 'head',
})

/**
* @see \Filament\Auth\Pages\PasswordReset\RequestPasswordReset::__invoke
* @see vendor/filament/filament/src/Auth/Pages/PasswordReset/RequestPasswordReset.php:7
* @route 'https://localhost/admin/password-reset/request'
*/
const RequestPasswordResetForm = (options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: RequestPasswordReset.url(options),
    method: 'get',
})

/**
* @see \Filament\Auth\Pages\PasswordReset\RequestPasswordReset::__invoke
* @see vendor/filament/filament/src/Auth/Pages/PasswordReset/RequestPasswordReset.php:7
* @route 'https://localhost/admin/password-reset/request'
*/
RequestPasswordResetForm.get = (options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: RequestPasswordReset.url(options),
    method: 'get',
})

/**
* @see \Filament\Auth\Pages\PasswordReset\RequestPasswordReset::__invoke
* @see vendor/filament/filament/src/Auth/Pages/PasswordReset/RequestPasswordReset.php:7
* @route 'https://localhost/admin/password-reset/request'
*/
RequestPasswordResetForm.head = (options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: RequestPasswordReset.url({
        [options?.mergeQuery ? 'mergeQuery' : 'query']: {
            _method: 'HEAD',
            ...(options?.query ?? options?.mergeQuery ?? {}),
        }
    }),
    method: 'get',
})

RequestPasswordReset.form = RequestPasswordResetForm

export default RequestPasswordReset