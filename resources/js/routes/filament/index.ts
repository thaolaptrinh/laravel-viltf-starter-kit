import admin from './admin'
import exports from './exports'
import imports from './imports'

const filament = {
    admin: Object.assign(admin, admin),
    exports: Object.assign(exports, exports),
    imports: Object.assign(imports, imports),
}

export default filament