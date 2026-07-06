import { queryParams, type RouteQueryOptions, type RouteDefinition, type RouteFormDefinition } from './../../../../../wayfinder'
/**
* @see \Filament\Auth\Pages\EmailVerification\EmailVerificationPrompt::__invoke
* @see vendor/filament/filament/src/Auth/Pages/EmailVerification/EmailVerificationPrompt.php:7
* @route 'https://localhost/admin/email-verification/prompt'
*/
const EmailVerificationPrompt = (options?: RouteQueryOptions): RouteDefinition<'get'> => ({
    url: EmailVerificationPrompt.url(options),
    method: 'get',
})

EmailVerificationPrompt.definition = {
    methods: ["get","head"],
    url: 'https://localhost/admin/email-verification/prompt',
} satisfies RouteDefinition<["get","head"]>

/**
* @see \Filament\Auth\Pages\EmailVerification\EmailVerificationPrompt::__invoke
* @see vendor/filament/filament/src/Auth/Pages/EmailVerification/EmailVerificationPrompt.php:7
* @route 'https://localhost/admin/email-verification/prompt'
*/
EmailVerificationPrompt.url = (options?: RouteQueryOptions) => {
    return EmailVerificationPrompt.definition.url + queryParams(options)
}

/**
* @see \Filament\Auth\Pages\EmailVerification\EmailVerificationPrompt::__invoke
* @see vendor/filament/filament/src/Auth/Pages/EmailVerification/EmailVerificationPrompt.php:7
* @route 'https://localhost/admin/email-verification/prompt'
*/
EmailVerificationPrompt.get = (options?: RouteQueryOptions): RouteDefinition<'get'> => ({
    url: EmailVerificationPrompt.url(options),
    method: 'get',
})

/**
* @see \Filament\Auth\Pages\EmailVerification\EmailVerificationPrompt::__invoke
* @see vendor/filament/filament/src/Auth/Pages/EmailVerification/EmailVerificationPrompt.php:7
* @route 'https://localhost/admin/email-verification/prompt'
*/
EmailVerificationPrompt.head = (options?: RouteQueryOptions): RouteDefinition<'head'> => ({
    url: EmailVerificationPrompt.url(options),
    method: 'head',
})

/**
* @see \Filament\Auth\Pages\EmailVerification\EmailVerificationPrompt::__invoke
* @see vendor/filament/filament/src/Auth/Pages/EmailVerification/EmailVerificationPrompt.php:7
* @route 'https://localhost/admin/email-verification/prompt'
*/
const EmailVerificationPromptForm = (options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: EmailVerificationPrompt.url(options),
    method: 'get',
})

/**
* @see \Filament\Auth\Pages\EmailVerification\EmailVerificationPrompt::__invoke
* @see vendor/filament/filament/src/Auth/Pages/EmailVerification/EmailVerificationPrompt.php:7
* @route 'https://localhost/admin/email-verification/prompt'
*/
EmailVerificationPromptForm.get = (options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: EmailVerificationPrompt.url(options),
    method: 'get',
})

/**
* @see \Filament\Auth\Pages\EmailVerification\EmailVerificationPrompt::__invoke
* @see vendor/filament/filament/src/Auth/Pages/EmailVerification/EmailVerificationPrompt.php:7
* @route 'https://localhost/admin/email-verification/prompt'
*/
EmailVerificationPromptForm.head = (options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: EmailVerificationPrompt.url({
        [options?.mergeQuery ? 'mergeQuery' : 'query']: {
            _method: 'HEAD',
            ...(options?.query ?? options?.mergeQuery ?? {}),
        }
    }),
    method: 'get',
})

EmailVerificationPrompt.form = EmailVerificationPromptForm

export default EmailVerificationPrompt