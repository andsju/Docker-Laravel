<!DOCTYPE html>
<html lang="sv">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>@yield('title', 'Laravel')</title>
    <link rel="stylesheet" href="/css/app.css">
    @vite('resources/scss/app.scss')
</head>
<body>
    <nav>
        <a href="/" class="brand">MyApp</a>
        <a href="/" @class(['active' => request()->is('/')])>Hem</a>
        <a href="/register" @class(['active' => request()->is('register')])>Registrera</a>
    </nav>

    <main>
        @yield('content')
    </main>
</body>
</html>
