import { queryParams, type RouteQueryOptions, type RouteDefinition, type RouteFormDefinition } from './../../../../../wayfinder'
/**
* @see \Filament\Auth\Pages\PasswordReset\RequestPasswordReset::__invoke
* @see vendor/filament/filament/src/Auth/Pages/PasswordReset/RequestPasswordReset.php:7
* @route 'https://localhost/admin/password-reset/request'
*/
export const request = (options?: RouteQueryOptions): RouteDefinition<'get'> => ({
    url: request.url(options),
    method: 'get',
})

request.definition = {
    methods: ["get","head"],
    url: 'https://localhost/admin/password-reset/request',
} satisfies RouteDefinition<["get","head"]>

/**
* @see \Filament\Auth\Pages\PasswordReset\RequestPasswordReset::__invoke
* @see vendor/filament/filament/src/Auth/Pages/PasswordReset/RequestPasswordReset.php:7
* @route 'https://localhost/admin/password-reset/request'
*/
request.url = (options?: RouteQueryOptions) => {
    return request.definition.url + queryParams(options)
}

/**
* @see \Filament\Auth\Pages\PasswordReset\RequestPasswordReset::__invoke
* @see vendor/filament/filament/src/Auth/Pages/PasswordReset/RequestPasswordReset.php:7
* @route 'https://localhost/admin/password-reset/request'
*/
request.get = (options?: RouteQueryOptions): RouteDefinition<'get'> => ({
    url: request.url(options),
    method: 'get',
})

/**
* @see \Filament\Auth\Pages\PasswordReset\RequestPasswordReset::__invoke
* @see vendor/filament/filament/src/Auth/Pages/PasswordReset/RequestPasswordReset.php:7
* @route 'https://localhost/admin/password-reset/request'
*/
request.head = (options?: RouteQueryOptions): RouteDefinition<'head'> => ({
    url: request.url(options),
    method: 'head',
})

/**
* @see \Filament\Auth\Pages\PasswordReset\RequestPasswordReset::__invoke
* @see vendor/filament/filament/src/Auth/Pages/PasswordReset/RequestPasswordReset.php:7
* @route 'https://localhost/admin/password-reset/request'
*/
const requestForm = (options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: request.url(options),
    method: 'get',
})

/**
* @see \Filament\Auth\Pages\PasswordReset\RequestPasswordReset::__invoke
* @see vendor/filament/filament/src/Auth/Pages/PasswordReset/RequestPasswordReset.php:7
* @route 'https://localhost/admin/password-reset/request'
*/
requestForm.get = (options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: request.url(options),
    method: 'get',
})

/**
* @see \Filament\Auth\Pages\PasswordReset\RequestPasswordReset::__invoke
* @see vendor/filament/filament/src/Auth/Pages/PasswordReset/RequestPasswordReset.php:7
* @route 'https://localhost/admin/password-reset/request'
*/
requestForm.head = (options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: request.url({
        [options?.mergeQuery ? 'mergeQuery' : 'query']: {
            _method: 'HEAD',
            ...(options?.query ?? options?.mergeQuery ?? {}),
        }
    }),
    method: 'get',
})

request.form = requestForm

/**
* @see \Filament\Auth\Pages\PasswordReset\ResetPassword::__invoke
* @see vendor/filament/filament/src/Auth/Pages/PasswordReset/ResetPassword.php:7
* @route 'https://localhost/admin/password-reset/reset'
*/
export const reset = (options?: RouteQueryOptions): RouteDefinition<'get'> => ({
    url: reset.url(options),
    method: 'get',
})

reset.definition = {
    methods: ["get","head"],
    url: 'https://localhost/admin/password-reset/reset',
} satisfies RouteDefinition<["get","head"]>

/**
* @see \Filament\Auth\Pages\PasswordReset\ResetPassword::__invoke
* @see vendor/filament/filament/src/Auth/Pages/PasswordReset/ResetPassword.php:7
* @route 'https://localhost/admin/password-reset/reset'
*/
reset.url = (options?: RouteQueryOptions) => {
    return reset.definition.url + queryParams(options)
}

/**
* @see \Filament\Auth\Pages\PasswordReset\ResetPassword::__invoke
* @see vendor/filament/filament/src/Auth/Pages/PasswordReset/ResetPassword.php:7
* @route 'https://localhost/admin/password-reset/reset'
*/
reset.get = (options?: RouteQueryOptions): RouteDefinition<'get'> => ({
    url: reset.url(options),
    method: 'get',
})

/**
* @see \Filament\Auth\Pages\PasswordReset\ResetPassword::__invoke
* @see vendor/filament/filament/src/Auth/Pages/PasswordReset/ResetPassword.php:7
* @route 'https://localhost/admin/password-reset/reset'
*/
reset.head = (options?: RouteQueryOptions): RouteDefinition<'head'> => ({
    url: reset.url(options),
    method: 'head',
})

/**
* @see \Filament\Auth\Pages\PasswordReset\ResetPassword::__invoke
* @see vendor/filament/filament/src/Auth/Pages/PasswordReset/ResetPassword.php:7
* @route 'https://localhost/admin/password-reset/reset'
*/
const resetForm = (options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: reset.url(options),
    method: 'get',
})

/**
* @see \Filament\Auth\Pages\PasswordReset\ResetPassword::__invoke
* @see vendor/filament/filament/src/Auth/Pages/PasswordReset/ResetPassword.php:7
* @route 'https://localhost/admin/password-reset/reset'
*/
resetForm.get = (options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: reset.url(options),
    method: 'get',
})

/**
* @see \Filament\Auth\Pages\PasswordReset\ResetPassword::__invoke
* @see vendor/filament/filament/src/Auth/Pages/PasswordReset/ResetPassword.php:7
* @route 'https://localhost/admin/password-reset/reset'
*/
resetForm.head = (options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: reset.url({
        [options?.mergeQuery ? 'mergeQuery' : 'query']: {
            _method: 'HEAD',
            ...(options?.query ?? options?.mergeQuery ?? {}),
        }
    }),
    method: 'get',
})

reset.form = resetForm

const passwordReset = {
    request: Object.assign(request, request),
    reset: Object.assign(reset, reset),
}

export default passwordReset