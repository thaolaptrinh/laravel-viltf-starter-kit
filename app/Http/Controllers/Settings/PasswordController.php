<?php

declare(strict_types=1);

namespace App\Http\Controllers\Settings;

use App\Actions\UpdateUserPassword;
use App\Data\PasswordData;
use App\Http\Controllers\Controller;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

final class PasswordController extends Controller
{
    public function __construct(
        private readonly UpdateUserPassword $updatePassword,
    ) {}

    public function edit(): Response
    {
        return Inertia::render('settings/Password');
    }

    public function update(Request $request): RedirectResponse
    {
        PasswordData::validate($request->all());

        $data = PasswordData::from($request);

        $this->updatePassword->handle($request->user(), $data);

        return back();
    }
}
