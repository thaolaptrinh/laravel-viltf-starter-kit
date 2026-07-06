import WelcomeController from './WelcomeController'
import Settings from './Settings'

const Controllers = {
    WelcomeController: Object.assign(WelcomeController, WelcomeController),
    Settings: Object.assign(Settings, Settings),
}

export default Controllers