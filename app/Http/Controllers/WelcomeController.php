<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Data\WelcomeData;
use Inertia\Inertia;
use Inertia\Response;
use Laravel\Fortify\Features;

final class WelcomeController extends Controller
{
    public function __invoke(): Response
    {
        $data = new WelcomeData(
            canRegister: Features::enabled(Features::registration()),
        );

        return Inertia::render('Welcome', $data->toArray());
    }
}
