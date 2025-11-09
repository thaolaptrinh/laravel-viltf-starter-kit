export type PasswordData = {
current_password: string,
password: string,
};
export type ProfileData = {
name: string,
email: string,
};
export type UserData = {
id: number,
name: string,
email: string,
avatar: string | null,
email_verified_at: string | null,
created_at: string,
updated_at: string,
};
export type WelcomeData = {
canRegister: boolean,
};
