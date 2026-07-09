<?php

declare(strict_types=1);

namespace App\Http\Controllers\Settings;

use App\Actions\DeleteUserAccount;
use App\Actions\UpdateUserProfile;
use App\Data\ProfileData;
use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Container\Attributes\CurrentUser;
use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Inertia\Inertia;
use Inertia\Response;

final class ProfileController extends Controller
{
    public function edit(Request $request, #[CurrentUser] User $user): Response
    {
        return Inertia::render('settings/Profile', [
            'mustVerifyEmail' => $user instanceof MustVerifyEmail, // @phpstan-ignore instanceof.alwaysFalse
            'status' => $request->session()->get('status'),
        ]);
    }

    public function update(Request $request, #[CurrentUser] User $user, UpdateUserProfile $updateUserProfile): RedirectResponse
    {
        $data = ProfileData::from($request);

        $updateUserProfile->handle($user, $data);

        return to_route('profile.edit');
    }

    public function destroy(Request $request, #[CurrentUser] User $user, DeleteUserAccount $deleteUserAccount): RedirectResponse
    {
        $request->validate([
            'password' => ['required', 'current_password'],
        ]);

        Auth::logout();

        /** @var string $password */
        $password = $request->input('password');

        $deleteUserAccount->handle(
            user: $user,
            password: $password,
        );

        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect('/');
    }
}
