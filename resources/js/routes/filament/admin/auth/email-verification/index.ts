import { queryParams, type RouteQueryOptions, type RouteDefinition, type RouteFormDefinition, applyUrlDefaults } from './../../../../../wayfinder'
/**
* @see \Filament\Auth\Pages\EmailVerification\EmailVerificationPrompt::__invoke
* @see vendor/filament/filament/src/Auth/Pages/EmailVerification/EmailVerificationPrompt.php:7
* @route 'https://localhost/admin/email-verification/prompt'
*/
export const prompt = (options?: RouteQueryOptions): RouteDefinition<'get'> => ({
    url: prompt.url(options),
    method: 'get',
})

prompt.definition = {
    methods: ["get","head"],
    url: 'https://localhost/admin/email-verification/prompt',
} satisfies RouteDefinition<["get","head"]>

/**
* @see \Filament\Auth\Pages\EmailVerification\EmailVerificationPrompt::__invoke
* @see vendor/filament/filament/src/Auth/Pages/EmailVerification/EmailVerificationPrompt.php:7
* @route 'https://localhost/admin/email-verification/prompt'
*/
prompt.url = (options?: RouteQueryOptions) => {
    return prompt.definition.url + queryParams(options)
}

/**
* @see \Filament\Auth\Pages\EmailVerification\EmailVerificationPrompt::__invoke
* @see vendor/filament/filament/src/Auth/Pages/EmailVerification/EmailVerificationPrompt.php:7
* @route 'https://localhost/admin/email-verification/prompt'
*/
prompt.get = (options?: RouteQueryOptions): RouteDefinition<'get'> => ({
    url: prompt.url(options),
    method: 'get',
})

/**
* @see \Filament\Auth\Pages\EmailVerification\EmailVerificationPrompt::__invoke
* @see vendor/filament/filament/src/Auth/Pages/EmailVerification/EmailVerificationPrompt.php:7
* @route 'https://localhost/admin/email-verification/prompt'
*/
prompt.head = (options?: RouteQueryOptions): RouteDefinition<'head'> => ({
    url: prompt.url(options),
    method: 'head',
})

/**
* @see \Filament\Auth\Pages\EmailVerification\EmailVerificationPrompt::__invoke
* @see vendor/filament/filament/src/Auth/Pages/EmailVerification/EmailVerificationPrompt.php:7
* @route 'https://localhost/admin/email-verification/prompt'
*/
const promptForm = (options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: prompt.url(options),
    method: 'get',
})

/**
* @see \Filament\Auth\Pages\EmailVerification\EmailVerificationPrompt::__invoke
* @see vendor/filament/filament/src/Auth/Pages/EmailVerification/EmailVerificationPrompt.php:7
* @route 'https://localhost/admin/email-verification/prompt'
*/
promptForm.get = (options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: prompt.url(options),
    method: 'get',
})

/**
* @see \Filament\Auth\Pages\EmailVerification\EmailVerificationPrompt::__invoke
* @see vendor/filament/filament/src/Auth/Pages/EmailVerification/EmailVerificationPrompt.php:7
* @route 'https://localhost/admin/email-verification/prompt'
*/
promptForm.head = (options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: prompt.url({
        [options?.mergeQuery ? 'mergeQuery' : 'query']: {
            _method: 'HEAD',
            ...(options?.query ?? options?.mergeQuery ?? {}),
        }
    }),
    method: 'get',
})

prompt.form = promptForm

/**
* @see \Filament\Auth\Http\Controllers\EmailVerificationController::__invoke
* @see vendor/filament/filament/src/Auth/Http/Controllers/EmailVerificationController.php:10
* @route 'https://localhost/admin/email-verification/verify/{id}/{hash}'
*/
export const verify = (args: { id: string | number, hash: string | number } | [id: string | number, hash: string | number ], options?: RouteQueryOptions): RouteDefinition<'get'> => ({
    url: verify.url(args, options),
    method: 'get',
})

verify.definition = {
    methods: ["get","head"],
    url: 'https://localhost/admin/email-verification/verify/{id}/{hash}',
} satisfies RouteDefinition<["get","head"]>

/**
* @see \Filament\Auth\Http\Controllers\EmailVerificationController::__invoke
* @see vendor/filament/filament/src/Auth/Http/Controllers/EmailVerificationController.php:10
* @route 'https://localhost/admin/email-verification/verify/{id}/{hash}'
*/
verify.url = (args: { id: string | number, hash: string | number } | [id: string | number, hash: string | number ], options?: RouteQueryOptions) => {
    if (Array.isArray(args)) {
        args = {
            id: args[0],
            hash: args[1],
        }
    }

    args = applyUrlDefaults(args)

    const parsedArgs = {
        id: args.id,
        hash: args.hash,
    }

    return verify.definition.url
            .replace('{id}', parsedArgs.id.toString())
            .replace('{hash}', parsedArgs.hash.toString())
            .replace(/\/+$/, '') + queryParams(options)
}

/**
* @see \Filament\Auth\Http\Controllers\EmailVerificationController::__invoke
* @see vendor/filament/filament/src/Auth/Http/Controllers/EmailVerificationController.php:10
* @route 'https://localhost/admin/email-verification/verify/{id}/{hash}'
*/
verify.get = (args: { id: string | number, hash: string | number } | [id: string | number, hash: string | number ], options?: RouteQueryOptions): RouteDefinition<'get'> => ({
    url: verify.url(args, options),
    method: 'get',
})

/**
* @see \Filament\Auth\Http\Controllers\EmailVerificationController::__invoke
* @see vendor/filament/filament/src/Auth/Http/Controllers/EmailVerificationController.php:10
* @route 'https://localhost/admin/email-verification/verify/{id}/{hash}'
*/
verify.head = (args: { id: string | number, hash: string | number } | [id: string | number, hash: string | number ], options?: RouteQueryOptions): RouteDefinition<'head'> => ({
    url: verify.url(args, options),
    method: 'head',
})

/**
* @see \Filament\Auth\Http\Controllers\EmailVerificationController::__invoke
* @see vendor/filament/filament/src/Auth/Http/Controllers/EmailVerificationController.php:10
* @route 'https://localhost/admin/email-verification/verify/{id}/{hash}'
*/
const verifyForm = (args: { id: string | number, hash: string | number } | [id: string | number, hash: string | number ], options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: verify.url(args, options),
    method: 'get',
})

/**
* @see \Filament\Auth\Http\Controllers\EmailVerificationController::__invoke
* @see vendor/filament/filament/src/Auth/Http/Controllers/EmailVerificationController.php:10
* @route 'https://localhost/admin/email-verification/verify/{id}/{hash}'
*/
verifyForm.get = (args: { id: string | number, hash: string | number } | [id: string | number, hash: string | number ], options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: verify.url(args, options),
    method: 'get',
})

/**
* @see \Filament\Auth\Http\Controllers\EmailVerificationController::__invoke
* @see vendor/filament/filament/src/Auth/Http/Controllers/EmailVerificationController.php:10
* @route 'https://localhost/admin/email-verification/verify/{id}/{hash}'
*/
verifyForm.head = (args: { id: string | number, hash: string | number } | [id: string | number, hash: string | number ], options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: verify.url(args, {
        [options?.mergeQuery ? 'mergeQuery' : 'query']: {
            _method: 'HEAD',
            ...(options?.query ?? options?.mergeQuery ?? {}),
        }
    }),
    method: 'get',
})

verify.form = verifyForm

const emailVerification = {
    prompt: Object.assign(prompt, prompt),
    verify: Object.assign(verify, verify),
}

export default emailVerification