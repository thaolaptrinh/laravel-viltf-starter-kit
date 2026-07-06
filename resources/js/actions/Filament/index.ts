import Auth from './Auth'
import Pages from './Pages'
import Actions from './Actions'

const Filament = {
    Auth: Object.assign(Auth, Auth),
    Pages: Object.assign(Pages, Pages),
    Actions: Object.assign(Actions, Actions),
}

export default Filament