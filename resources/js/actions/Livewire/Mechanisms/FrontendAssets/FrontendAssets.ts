import { queryParams, type RouteQueryOptions, type RouteDefinition, type RouteFormDefinition } from './../../../../wayfinder'
/**
* @see \Livewire\Mechanisms\FrontendAssets\FrontendAssets::returnJavaScriptAsFile
* @see vendor/livewire/livewire/src/Mechanisms/FrontendAssets/FrontendAssets.php:81
* @route '/livewire-4aeeedbb/livewire.js'
*/
export const returnJavaScriptAsFile = (options?: RouteQueryOptions): RouteDefinition<'get'> => ({
    url: returnJavaScriptAsFile.url(options),
    method: 'get',
})

returnJavaScriptAsFile.definition = {
    methods: ["get","head"],
    url: '/livewire-4aeeedbb/livewire.js',
} satisfies RouteDefinition<["get","head"]>

/**
* @see \Livewire\Mechanisms\FrontendAssets\FrontendAssets::returnJavaScriptAsFile
* @see vendor/livewire/livewire/src/Mechanisms/FrontendAssets/FrontendAssets.php:81
* @route '/livewire-4aeeedbb/livewire.js'
*/
returnJavaScriptAsFile.url = (options?: RouteQueryOptions) => {
    return returnJavaScriptAsFile.definition.url + queryParams(options)
}

/**
* @see \Livewire\Mechanisms\FrontendAssets\FrontendAssets::returnJavaScriptAsFile
* @see vendor/livewire/livewire/src/Mechanisms/FrontendAssets/FrontendAssets.php:81
* @route '/livewire-4aeeedbb/livewire.js'
*/
returnJavaScriptAsFile.get = (options?: RouteQueryOptions): RouteDefinition<'get'> => ({
    url: returnJavaScriptAsFile.url(options),
    method: 'get',
})

/**
* @see \Livewire\Mechanisms\FrontendAssets\FrontendAssets::returnJavaScriptAsFile
* @see vendor/livewire/livewire/src/Mechanisms/FrontendAssets/FrontendAssets.php:81
* @route '/livewire-4aeeedbb/livewire.js'
*/
returnJavaScriptAsFile.head = (options?: RouteQueryOptions): RouteDefinition<'head'> => ({
    url: returnJavaScriptAsFile.url(options),
    method: 'head',
})

/**
* @see \Livewire\Mechanisms\FrontendAssets\FrontendAssets::returnJavaScriptAsFile
* @see vendor/livewire/livewire/src/Mechanisms/FrontendAssets/FrontendAssets.php:81
* @route '/livewire-4aeeedbb/livewire.js'
*/
const returnJavaScriptAsFileForm = (options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: returnJavaScriptAsFile.url(options),
    method: 'get',
})

/**
* @see \Livewire\Mechanisms\FrontendAssets\FrontendAssets::returnJavaScriptAsFile
* @see vendor/livewire/livewire/src/Mechanisms/FrontendAssets/FrontendAssets.php:81
* @route '/livewire-4aeeedbb/livewire.js'
*/
returnJavaScriptAsFileForm.get = (options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: returnJavaScriptAsFile.url(options),
    method: 'get',
})

/**
* @see \Livewire\Mechanisms\FrontendAssets\FrontendAssets::returnJavaScriptAsFile
* @see vendor/livewire/livewire/src/Mechanisms/FrontendAssets/FrontendAssets.php:81
* @route '/livewire-4aeeedbb/livewire.js'
*/
returnJavaScriptAsFileForm.head = (options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: returnJavaScriptAsFile.url({
        [options?.mergeQuery ? 'mergeQuery' : 'query']: {
            _method: 'HEAD',
            ...(options?.query ?? options?.mergeQuery ?? {}),
        }
    }),
    method: 'get',
})

returnJavaScriptAsFile.form = returnJavaScriptAsFileForm

/**
* @see \Livewire\Mechanisms\FrontendAssets\FrontendAssets::maps
* @see vendor/livewire/livewire/src/Mechanisms/FrontendAssets/FrontendAssets.php:94
* @route '/livewire-4aeeedbb/livewire.min.js.map'
*/
export const maps = (options?: RouteQueryOptions): RouteDefinition<'get'> => ({
    url: maps.url(options),
    method: 'get',
})

maps.definition = {
    methods: ["get","head"],
    url: '/livewire-4aeeedbb/livewire.min.js.map',
} satisfies RouteDefinition<["get","head"]>

/**
* @see \Livewire\Mechanisms\FrontendAssets\FrontendAssets::maps
* @see vendor/livewire/livewire/src/Mechanisms/FrontendAssets/FrontendAssets.php:94
* @route '/livewire-4aeeedbb/livewire.min.js.map'
*/
maps.url = (options?: RouteQueryOptions) => {
    return maps.definition.url + queryParams(options)
}

/**
* @see \Livewire\Mechanisms\FrontendAssets\FrontendAssets::maps
* @see vendor/livewire/livewire/src/Mechanisms/FrontendAssets/FrontendAssets.php:94
* @route '/livewire-4aeeedbb/livewire.min.js.map'
*/
maps.get = (options?: RouteQueryOptions): RouteDefinition<'get'> => ({
    url: maps.url(options),
    method: 'get',
})

/**
* @see \Livewire\Mechanisms\FrontendAssets\FrontendAssets::maps
* @see vendor/livewire/livewire/src/Mechanisms/FrontendAssets/FrontendAssets.php:94
* @route '/livewire-4aeeedbb/livewire.min.js.map'
*/
maps.head = (options?: RouteQueryOptions): RouteDefinition<'head'> => ({
    url: maps.url(options),
    method: 'head',
})

/**
* @see \Livewire\Mechanisms\FrontendAssets\FrontendAssets::maps
* @see vendor/livewire/livewire/src/Mechanisms/FrontendAssets/FrontendAssets.php:94
* @route '/livewire-4aeeedbb/livewire.min.js.map'
*/
const mapsForm = (options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: maps.url(options),
    method: 'get',
})

/**
* @see \Livewire\Mechanisms\FrontendAssets\FrontendAssets::maps
* @see vendor/livewire/livewire/src/Mechanisms/FrontendAssets/FrontendAssets.php:94
* @route '/livewire-4aeeedbb/livewire.min.js.map'
*/
mapsForm.get = (options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: maps.url(options),
    method: 'get',
})

/**
* @see \Livewire\Mechanisms\FrontendAssets\FrontendAssets::maps
* @see vendor/livewire/livewire/src/Mechanisms/FrontendAssets/FrontendAssets.php:94
* @route '/livewire-4aeeedbb/livewire.min.js.map'
*/
mapsForm.head = (options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: maps.url({
        [options?.mergeQuery ? 'mergeQuery' : 'query']: {
            _method: 'HEAD',
            ...(options?.query ?? options?.mergeQuery ?? {}),
        }
    }),
    method: 'get',
})

maps.form = mapsForm

/**
* @see \Livewire\Mechanisms\FrontendAssets\FrontendAssets::cspMaps
* @see vendor/livewire/livewire/src/Mechanisms/FrontendAssets/FrontendAssets.php:103
* @route '/livewire-4aeeedbb/livewire.csp.min.js.map'
*/
export const cspMaps = (options?: RouteQueryOptions): RouteDefinition<'get'> => ({
    url: cspMaps.url(options),
    method: 'get',
})

cspMaps.definition = {
    methods: ["get","head"],
    url: '/livewire-4aeeedbb/livewire.csp.min.js.map',
} satisfies RouteDefinition<["get","head"]>

/**
* @see \Livewire\Mechanisms\FrontendAssets\FrontendAssets::cspMaps
* @see vendor/livewire/livewire/src/Mechanisms/FrontendAssets/FrontendAssets.php:103
* @route '/livewire-4aeeedbb/livewire.csp.min.js.map'
*/
cspMaps.url = (options?: RouteQueryOptions) => {
    return cspMaps.definition.url + queryParams(options)
}

/**
* @see \Livewire\Mechanisms\FrontendAssets\FrontendAssets::cspMaps
* @see vendor/livewire/livewire/src/Mechanisms/FrontendAssets/FrontendAssets.php:103
* @route '/livewire-4aeeedbb/livewire.csp.min.js.map'
*/
cspMaps.get = (options?: RouteQueryOptions): RouteDefinition<'get'> => ({
    url: cspMaps.url(options),
    method: 'get',
})

/**
* @see \Livewire\Mechanisms\FrontendAssets\FrontendAssets::cspMaps
* @see vendor/livewire/livewire/src/Mechanisms/FrontendAssets/FrontendAssets.php:103
* @route '/livewire-4aeeedbb/livewire.csp.min.js.map'
*/
cspMaps.head = (options?: RouteQueryOptions): RouteDefinition<'head'> => ({
    url: cspMaps.url(options),
    method: 'head',
})

/**
* @see \Livewire\Mechanisms\FrontendAssets\FrontendAssets::cspMaps
* @see vendor/livewire/livewire/src/Mechanisms/FrontendAssets/FrontendAssets.php:103
* @route '/livewire-4aeeedbb/livewire.csp.min.js.map'
*/
const cspMapsForm = (options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: cspMaps.url(options),
    method: 'get',
})

/**
* @see \Livewire\Mechanisms\FrontendAssets\FrontendAssets::cspMaps
* @see vendor/livewire/livewire/src/Mechanisms/FrontendAssets/FrontendAssets.php:103
* @route '/livewire-4aeeedbb/livewire.csp.min.js.map'
*/
cspMapsForm.get = (options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: cspMaps.url(options),
    method: 'get',
})

/**
* @see \Livewire\Mechanisms\FrontendAssets\FrontendAssets::cspMaps
* @see vendor/livewire/livewire/src/Mechanisms/FrontendAssets/FrontendAssets.php:103
* @route '/livewire-4aeeedbb/livewire.csp.min.js.map'
*/
cspMapsForm.head = (options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: cspMaps.url({
        [options?.mergeQuery ? 'mergeQuery' : 'query']: {
            _method: 'HEAD',
            ...(options?.query ?? options?.mergeQuery ?? {}),
        }
    }),
    method: 'get',
})

cspMaps.form = cspMapsForm

const FrontendAssets = { returnJavaScriptAsFile, maps, cspMaps }

export default FrontendAssets