<?php

declare(strict_types=1);

namespace App\Http\Controllers\Settings;

use App\Actions\UpdateUserPassword;
use App\Data\PasswordData;
use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Container\Attributes\CurrentUser;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

final class PasswordController extends Controller
{
    public function edit(): Response
    {
        return Inertia::render('settings/Password');
    }

    public function update(Request $request, #[CurrentUser] User $user, UpdateUserPassword $updateUserPassword): RedirectResponse
    {
        PasswordData::validate($request->all());

        $data = PasswordData::from($request);

        $updateUserPassword->handle($user, $data);

        return back();
    }
}
