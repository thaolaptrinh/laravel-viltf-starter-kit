<a id="top"></a>

# 🚀 Laravel VILTF Starter Kit

<div align="center">

A modern, full-featured Laravel starter kit with **Vue 3**, **Inertia.js**, **Tailwind CSS**, and **Filament** — ready for building fullstack applications and admin dashboards.

[![Laravel](https://img.shields.io/badge/Laravel-13.x-FF2D20?style=for-the-badge&logo=laravel)](https://laravel.com)
[![Vue](https://img.shields.io/badge/Vue-3.5-4FC08D?style=for-the-badge&logo=vue.js)](https://vuejs.org)
[![Inertia](https://img.shields.io/badge/Inertia-3.x-9553E9?style=for-the-badge)](https://inertiajs.com)
[![Tailwind CSS](https://img.shields.io/badge/Tailwind-4.x-38B2AC?style=for-the-badge&logo=tailwind-css)](https://tailwindcss.com)
[![Filament](https://img.shields.io/badge/Filament-5.x-F59E0B?style=for-the-badge)](https://filamentphp.com)
[![PHP](https://img.shields.io/badge/PHP-8.5-777BB4?style=for-the-badge&logo=php)](https://php.net)
[![Pest](https://img.shields.io/badge/Pest-4.x-FF3064?style=for-the-badge)](https://pestphp.com)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

[![GitHub Stars](https://img.shields.io/github/stars/thaolaptrinh/laravel-viltf-starter-kit?style=social)](https://github.com/thaolaptrinh/laravel-viltf-starter-kit/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/thaolaptrinh/laravel-viltf-starter-kit?style=social)](https://github.com/thaolaptrinh/laravel-viltf-starter-kit/network/members)

</div>

---

## ✨ What's Included

- **Vue 3** + **TypeScript** + **Inertia.js v3** — Modern SPA-like experience with SSR support
- **Tailwind CSS v4** — Utility-first styling with dark mode
- **Filament v5** — Beautiful admin panel out of the box (mounted at `/admin`)
- **Laravel Fortify** — Complete authentication: login, registration, email verification, password reset, **2FA** (QR + recovery codes), and **passkeys**
- **Laravel Wayfinder** — Type-safe route generation for TypeScript
- **Reka UI** — Beautiful, accessible headless Vue components
- **@lucide/vue** + **VueUse** — Icon set and composable utilities
- **Spatie laravel-data** + **laravel-typescript-transformer** — Typed data objects with automatic TypeScript type generation
- **Laravel Pail** — Real-time log tailing during development
- **Laravel Boost** — Development tooling and MCP server integration
- **Pest PHP v4** — Modern testing framework with browser testing support (Playwright)
- Code quality tools: **Pint**, **Rector**, **Larastan**, **ESLint**, **Prettier** (via [vite-plus](https://viteplus.dev))

---

## 📋 Requirements

| Tool     | Version                                                    |
| -------- | ---------------------------------------------------------- |
| PHP      | `8.5+`                                                     |
| Composer | `2.x`                                                      |
| Node.js  | `20+` (with `pnpm`)                                        |
| Docker   | required for [Laravel Sail](https://laravel.com/docs/sail) |

> This project ships with **Laravel Sail** (Docker). All commands below run inside Sail — no local PHP/Postgres setup required.

---

## 📦 Installation

### Quick start

```bash
git clone https://github.com/thaolaptrinh/laravel-viltf-starter-kit.git
cd laravel-viltf-starter-kit
composer setup
```

The `composer setup` script runs the full bootstrap for you:

1. `composer install`
2. Copies `.env.example` → `.env`
3. Generates the app key
4. Runs migrations
5. `pnpm install`
6. `pnpm run build`

### Start the dev environment

```bash
vendor/bin/sail up -d        # start Postgres + Redis + app
vendor/bin/sail composer run dev
```

Then visit **http://localhost** (app) and **http://localhost/admin** (Filament panel).

---

## 📚 Documentation

- [Laravel](https://laravel.com/docs) · [Inertia.js](https://inertiajs.com) · [Vue.js](https://vuejs.org/docs)
- [Tailwind CSS v4](https://tailwindcss.com/docs) · [Filament](https://filamentphp.com/docs) · [Livewire](https://livewire.laravel.com/docs)
- [Laravel Fortify](https://laravel.com/docs/fortify) · [Wayfinder](https://github.com/laravel/wayfinder) · [Laravel Boost](https://github.com/laravel/boost)
- [Pest](https://pestphp.com) · [Reka UI](https://reka-ui.com) · [VueUse](https://vueuse.org) · [Rector](https://getrector.org/documentation)

---

## 🤝 Contributing

Pull requests are welcome! Please ensure the test suite passes before submitting:

```bash
vendor/bin/sail composer test
```

---

## 📝 License

Created by [@thaolaptrinh](https://github.com/thaolaptrinh) — released under the [MIT License](LICENSE).

---

<div align="center">

**Built with ❤️ using Laravel, Vue, Inertia, Tailwind CSS, and Filament**

⭐ Star this repo if you find it helpful!

[⬆ Back to Top](#top)

</div>
