<?php

declare(strict_types=1);

namespace App\Http\Controllers\Settings;

use App\Actions\DeleteUserAccount;
use App\Actions\UpdateUserProfile;
use App\Data\ProfileData;
use App\Http\Controllers\Controller;
use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

final class ProfileController extends Controller
{
    public function __construct(
        private readonly UpdateUserProfile $updateProfile,
        private readonly DeleteUserAccount $deleteAccount,
    ) {}

    public function edit(Request $request): Response
    {
        return Inertia::render('settings/Profile', [
            'mustVerifyEmail' => $request->user() instanceof MustVerifyEmail, // @phpstan-ignore instanceof.alwaysFalse
            'status' => $request->session()->get('status'),
        ]);
    }

    public function update(Request $request): RedirectResponse
    {
        $data = ProfileData::from($request);

        $this->updateProfile->handle($request->user(), $data);

        return to_route('profile.edit');
    }

    public function destroy(Request $request): RedirectResponse
    {
        $request->validate([
            'password' => ['required', 'current_password'],
        ]);

        $user = $request->user();

        auth()->logout();

        $this->deleteAccount->handle(
            $user,
            $request->input('password'),
        );

        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect('/');
    }
}
