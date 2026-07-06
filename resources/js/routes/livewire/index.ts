import { queryParams, type RouteQueryOptions, type RouteDefinition, type RouteFormDefinition, applyUrlDefaults } from './../../wayfinder'
/**
* @see \Livewire\Features\SupportFileUploads\FileUploadController::uploadFile
* @see vendor/livewire/livewire/src/Features/SupportFileUploads/FileUploadController.php:27
* @route '/livewire-4aeeedbb/upload-file'
*/
export const uploadFile = (options?: RouteQueryOptions): RouteDefinition<'post'> => ({
    url: uploadFile.url(options),
    method: 'post',
})

uploadFile.definition = {
    methods: ["post"],
    url: '/livewire-4aeeedbb/upload-file',
} satisfies RouteDefinition<["post"]>

/**
* @see \Livewire\Features\SupportFileUploads\FileUploadController::uploadFile
* @see vendor/livewire/livewire/src/Features/SupportFileUploads/FileUploadController.php:27
* @route '/livewire-4aeeedbb/upload-file'
*/
uploadFile.url = (options?: RouteQueryOptions) => {
    return uploadFile.definition.url + queryParams(options)
}

/**
* @see \Livewire\Features\SupportFileUploads\FileUploadController::uploadFile
* @see vendor/livewire/livewire/src/Features/SupportFileUploads/FileUploadController.php:27
* @route '/livewire-4aeeedbb/upload-file'
*/
uploadFile.post = (options?: RouteQueryOptions): RouteDefinition<'post'> => ({
    url: uploadFile.url(options),
    method: 'post',
})

/**
* @see \Livewire\Features\SupportFileUploads\FileUploadController::uploadFile
* @see vendor/livewire/livewire/src/Features/SupportFileUploads/FileUploadController.php:27
* @route '/livewire-4aeeedbb/upload-file'
*/
const uploadFileForm = (options?: RouteQueryOptions): RouteFormDefinition<'post'> => ({
    action: uploadFile.url(options),
    method: 'post',
})

/**
* @see \Livewire\Features\SupportFileUploads\FileUploadController::uploadFile
* @see vendor/livewire/livewire/src/Features/SupportFileUploads/FileUploadController.php:27
* @route '/livewire-4aeeedbb/upload-file'
*/
uploadFileForm.post = (options?: RouteQueryOptions): RouteFormDefinition<'post'> => ({
    action: uploadFile.url(options),
    method: 'post',
})

uploadFile.form = uploadFileForm

/**
* @see \Livewire\Features\SupportFileUploads\FilePreviewController::previewFile
* @see vendor/livewire/livewire/src/Features/SupportFileUploads/FilePreviewController.php:18
* @route '/livewire-4aeeedbb/preview-file/{filename}'
*/
export const previewFile = (args: { filename: string | number } | [filename: string | number ] | string | number, options?: RouteQueryOptions): RouteDefinition<'get'> => ({
    url: previewFile.url(args, options),
    method: 'get',
})

previewFile.definition = {
    methods: ["get","head"],
    url: '/livewire-4aeeedbb/preview-file/{filename}',
} satisfies RouteDefinition<["get","head"]>

/**
* @see \Livewire\Features\SupportFileUploads\FilePreviewController::previewFile
* @see vendor/livewire/livewire/src/Features/SupportFileUploads/FilePreviewController.php:18
* @route '/livewire-4aeeedbb/preview-file/{filename}'
*/
previewFile.url = (args: { filename: string | number } | [filename: string | number ] | string | number, options?: RouteQueryOptions) => {
    if (typeof args === 'string' || typeof args === 'number') {
        args = { filename: args }
    }

    if (Array.isArray(args)) {
        args = {
            filename: args[0],
        }
    }

    args = applyUrlDefaults(args)

    const parsedArgs = {
        filename: args.filename,
    }

    return previewFile.definition.url
            .replace('{filename}', parsedArgs.filename.toString())
            .replace(/\/+$/, '') + queryParams(options)
}

/**
* @see \Livewire\Features\SupportFileUploads\FilePreviewController::previewFile
* @see vendor/livewire/livewire/src/Features/SupportFileUploads/FilePreviewController.php:18
* @route '/livewire-4aeeedbb/preview-file/{filename}'
*/
previewFile.get = (args: { filename: string | number } | [filename: string | number ] | string | number, options?: RouteQueryOptions): RouteDefinition<'get'> => ({
    url: previewFile.url(args, options),
    method: 'get',
})

/**
* @see \Livewire\Features\SupportFileUploads\FilePreviewController::previewFile
* @see vendor/livewire/livewire/src/Features/SupportFileUploads/FilePreviewController.php:18
* @route '/livewire-4aeeedbb/preview-file/{filename}'
*/
previewFile.head = (args: { filename: string | number } | [filename: string | number ] | string | number, options?: RouteQueryOptions): RouteDefinition<'head'> => ({
    url: previewFile.url(args, options),
    method: 'head',
})

/**
* @see \Livewire\Features\SupportFileUploads\FilePreviewController::previewFile
* @see vendor/livewire/livewire/src/Features/SupportFileUploads/FilePreviewController.php:18
* @route '/livewire-4aeeedbb/preview-file/{filename}'
*/
const previewFileForm = (args: { filename: string | number } | [filename: string | number ] | string | number, options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: previewFile.url(args, options),
    method: 'get',
})

/**
* @see \Livewire\Features\SupportFileUploads\FilePreviewController::previewFile
* @see vendor/livewire/livewire/src/Features/SupportFileUploads/FilePreviewController.php:18
* @route '/livewire-4aeeedbb/preview-file/{filename}'
*/
previewFileForm.get = (args: { filename: string | number } | [filename: string | number ] | string | number, options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: previewFile.url(args, options),
    method: 'get',
})

/**
* @see \Livewire\Features\SupportFileUploads\FilePreviewController::previewFile
* @see vendor/livewire/livewire/src/Features/SupportFileUploads/FilePreviewController.php:18
* @route '/livewire-4aeeedbb/preview-file/{filename}'
*/
previewFileForm.head = (args: { filename: string | number } | [filename: string | number ] | string | number, options?: RouteQueryOptions): RouteFormDefinition<'get'> => ({
    action: previewFile.url(args, {
        [options?.mergeQuery ? 'mergeQuery' : 'query']: {
            _method: 'HEAD',
            ...(options?.query ?? options?.mergeQuery ?? {}),
        }
    }),
    method: 'get',
})

previewFile.form = previewFileForm

const livewire = {
    uploadFile: Object.assign(uploadFile, uploadFile),
    previewFile: Object.assign(previewFile, previewFile),
}

export default livewire