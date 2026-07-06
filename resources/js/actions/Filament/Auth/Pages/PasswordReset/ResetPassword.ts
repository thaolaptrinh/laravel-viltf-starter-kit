import { queryParams, type RouteQueryOptions, type RouteDefinition, type RouteFormDefinition } from './../../../../../wayfinder'
/**
* @see \Filament\Auth\Pages\PasswordReset\ResetPassword::__invoke
* @see vendor/filament/filament/src/Auth/Pages/PasswordReset/ResetPassword.php:7
* @route 'https://localhost/admin/password-reset/reset'
*/
const ResetPassword = (options?: RouteQueryOptions): RouteDefinition<'get'> => ({
    url: ResetPassword.url(options),
    method: 'get',
})

ResetPassword.definition = {
    methods: ["get","head"],
    url: 'https://localhost/admin/password-reset/reset',
} satisfies RouteDefinition<["get","head"]>

/**
* @see \Filament\Auth\Pages\PasswordReset\ResetPassword::__invoke
* @see vendor/filament/filament/src/Auth/Pages/PasswordReset/ResetPassword.php:7
* @route 'https://localhost/admin/password-reset/reset'
*/
ResetPassword.url = (options?: RouteQueryOptions) => {
    return ResetPassword.definition.url + queryParams(options)
}

/**
* @see \Filament\Auth\Pages\PasswordReset\ResetPassword::__invoke
* @see vendor/filament/filament/src/Auth/Pages/PasswordReset/ResetPassword.php:7
* @route 'https://localhost/admin/password-reset/reset'
*/
ResetPassword.get = (options?: RouteQueryOptions): RouteDefinition<'get'> => ({
    url: ResetPassword.url(options),
    method: 'get',
})

/**
* @see \Filament\Auth\Pages\PasswordReset\ResetPassword::__invoke
* @see vendor/filament/filament/src/Auth/Pages/PasswordReset/ResetPassword.php:7
* @route 'https://localhost/admin/password-reset/reset'
*/
ResetPassword.head = (options?: RouteQueryOptions): RouteDefinition<'head'> => ({
    url: ResetPassword.url(options),
    method: 'head',
})

/**
* @see \Filament\Auth\Pages\PasswordReset\ResetPassword::__invoke
* @see vendor/filament/filament/src/Auth/Pages/PasswordReset/ResetPassword.php:7
* @route 'https://localhost/admin/password-reset/reset'
*/
const ResetPasswordForm = (options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: ResetPassword.url(options),
    method: 'get',
})

/**
* @see \Filament\Auth\Pages\PasswordReset\ResetPassword::__invoke
* @see vendor/filament/filament/src/Auth/Pages/PasswordReset/ResetPassword.php:7
* @route 'https://localhost/admin/password-reset/reset'
*/
ResetPasswordForm.get = (options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: ResetPassword.url(options),
    method: 'get',
})

/**
* @see \Filament\Auth\Pages\PasswordReset\ResetPassword::__invoke
* @see vendor/filament/filament/src/Auth/Pages/PasswordReset/ResetPassword.php:7
* @route 'https://localhost/admin/password-reset/reset'
*/
ResetPasswordForm.head = (options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: ResetPassword.url({
        [options?.mergeQuery ? 'mergeQuery' : 'query']: {
            _method: 'HEAD',
            ...(options?.query ?? options?.mergeQuery ?? {}),
        }
    }),
    method: 'get',
})

ResetPassword.form = ResetPasswordForm

export default ResetPassword