import PasswordReset from './PasswordReset'
import EditProfile from './EditProfile'
import EmailVerification from './EmailVerification'

const Pages = {
    PasswordReset: Object.assign(PasswordReset, PasswordReset),
    EditProfile: Object.assign(EditProfile, EditProfile),
    EmailVerification: Object.assign(EmailVerification, EmailVerification),
}

export default Pages