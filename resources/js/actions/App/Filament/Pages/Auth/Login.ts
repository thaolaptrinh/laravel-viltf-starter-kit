import { queryParams, type RouteQueryOptions, type RouteDefinition, type RouteFormDefinition } from './../../../../../wayfinder'
/**
* @see \App\Filament\Pages\Auth\Login::__invoke
* @see app/Filament/Pages/Auth/Login.php:7
* @route 'https://localhost/admin/login'
*/
const Login = (options?: RouteQueryOptions): RouteDefinition<'get'> => ({
    url: Login.url(options),
    method: 'get',
})

Login.definition = {
    methods: ["get","head"],
    url: 'https://localhost/admin/login',
} satisfies RouteDefinition<["get","head"]>

/**
* @see \App\Filament\Pages\Auth\Login::__invoke
* @see app/Filament/Pages/Auth/Login.php:7
* @route 'https://localhost/admin/login'
*/
Login.url = (options?: RouteQueryOptions) => {
    return Login.definition.url + queryParams(options)
}

/**
* @see \App\Filament\Pages\Auth\Login::__invoke
* @see app/Filament/Pages/Auth/Login.php:7
* @route 'https://localhost/admin/login'
*/
Login.get = (options?: RouteQueryOptions): RouteDefinition<'get'> => ({
    url: Login.url(options),
    method: 'get',
})

/**
* @see \App\Filament\Pages\Auth\Login::__invoke
* @see app/Filament/Pages/Auth/Login.php:7
* @route 'https://localhost/admin/login'
*/
Login.head = (options?: RouteQueryOptions): RouteDefinition<'head'> => ({
    url: Login.url(options),
    method: 'head',
})

/**
* @see \App\Filament\Pages\Auth\Login::__invoke
* @see app/Filament/Pages/Auth/Login.php:7
* @route 'https://localhost/admin/login'
*/
const LoginForm = (options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: Login.url(options),
    method: 'get',
})

/**
* @see \App\Filament\Pages\Auth\Login::__invoke
* @see app/Filament/Pages/Auth/Login.php:7
* @route 'https://localhost/admin/login'
*/
LoginForm.get = (options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: Login.url(options),
    method: 'get',
})

/**
* @see \App\Filament\Pages\Auth\Login::__invoke
* @see app/Filament/Pages/Auth/Login.php:7
* @route 'https://localhost/admin/login'
*/
LoginForm.head = (options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: Login.url({
        [options?.mergeQuery ? 'mergeQuery' : 'query']: {
            _method: 'HEAD',
            ...(options?.query ?? options?.mergeQuery ?? {}),
        }
    }),
    method: 'get',
})

Login.form = LoginForm

export default Login