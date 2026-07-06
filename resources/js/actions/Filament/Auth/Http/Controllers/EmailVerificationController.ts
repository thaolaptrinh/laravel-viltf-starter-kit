import { queryParams, type RouteQueryOptions, type RouteDefinition, type RouteFormDefinition, applyUrlDefaults } from './../../../../../wayfinder'
/**
* @see \Filament\Auth\Http\Controllers\EmailVerificationController::__invoke
* @see vendor/filament/filament/src/Auth/Http/Controllers/EmailVerificationController.php:10
* @route 'https://localhost/admin/email-verification/verify/{id}/{hash}'
*/
const EmailVerificationController = (args: { id: string | number, hash: string | number } | [id: string | number, hash: string | number ], options?: RouteQueryOptions): RouteDefinition<'get'> => ({
    url: EmailVerificationController.url(args, options),
    method: 'get',
})

EmailVerificationController.definition = {
    methods: ["get","head"],
    url: 'https://localhost/admin/email-verification/verify/{id}/{hash}',
} satisfies RouteDefinition<["get","head"]>

/**
* @see \Filament\Auth\Http\Controllers\EmailVerificationController::__invoke
* @see vendor/filament/filament/src/Auth/Http/Controllers/EmailVerificationController.php:10
* @route 'https://localhost/admin/email-verification/verify/{id}/{hash}'
*/
EmailVerificationController.url = (args: { id: string | number, hash: string | number } | [id: string | number, hash: string | number ], options?: RouteQueryOptions) => {
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

    return EmailVerificationController.definition.url
            .replace('{id}', parsedArgs.id.toString())
            .replace('{hash}', parsedArgs.hash.toString())
            .replace(/\/+$/, '') + queryParams(options)
}

/**
* @see \Filament\Auth\Http\Controllers\EmailVerificationController::__invoke
* @see vendor/filament/filament/src/Auth/Http/Controllers/EmailVerificationController.php:10
* @route 'https://localhost/admin/email-verification/verify/{id}/{hash}'
*/
EmailVerificationController.get = (args: { id: string | number, hash: string | number } | [id: string | number, hash: string | number ], options?: RouteQueryOptions): RouteDefinition<'get'> => ({
    url: EmailVerificationController.url(args, options),
    method: 'get',
})

/**
* @see \Filament\Auth\Http\Controllers\EmailVerificationController::__invoke
* @see vendor/filament/filament/src/Auth/Http/Controllers/EmailVerificationController.php:10
* @route 'https://localhost/admin/email-verification/verify/{id}/{hash}'
*/
EmailVerificationController.head = (args: { id: string | number, hash: string | number } | [id: string | number, hash: string | number ], options?: RouteQueryOptions): RouteDefinition<'head'> => ({
    url: EmailVerificationController.url(args, options),
    method: 'head',
})

/**
* @see \Filament\Auth\Http\Controllers\EmailVerificationController::__invoke
* @see vendor/filament/filament/src/Auth/Http/Controllers/EmailVerificationController.php:10
* @route 'https://localhost/admin/email-verification/verify/{id}/{hash}'
*/
const EmailVerificationControllerForm = (args: { id: string | number, hash: string | number } | [id: string | number, hash: string | number ], options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: EmailVerificationController.url(args, options),
    method: 'get',
})

/**
* @see \Filament\Auth\Http\Controllers\EmailVerificationController::__invoke
* @see vendor/filament/filament/src/Auth/Http/Controllers/EmailVerificationController.php:10
* @route 'https://localhost/admin/email-verification/verify/{id}/{hash}'
*/
EmailVerificationControllerForm.get = (args: { id: string | number, hash: string | number } | [id: string | number, hash: string | number ], options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: EmailVerificationController.url(args, options),
    method: 'get',
})

/**
* @see \Filament\Auth\Http\Controllers\EmailVerificationController::__invoke
* @see vendor/filament/filament/src/Auth/Http/Controllers/EmailVerificationController.php:10
* @route 'https://localhost/admin/email-verification/verify/{id}/{hash}'
*/
EmailVerificationControllerForm.head = (args: { id: string | number, hash: string | number } | [id: string | number, hash: string | number ], options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: EmailVerificationController.url(args, {
        [options?.mergeQuery ? 'mergeQuery' : 'query']: {
            _method: 'HEAD',
            ...(options?.query ?? options?.mergeQuery ?? {}),
        }
    }),
    method: 'get',
})

EmailVerificationController.form = EmailVerificationControllerForm

export default EmailVerificationController