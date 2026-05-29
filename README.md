# Laravel Docker-projekt

En Laravel-applikation som körs i Docker med Apache och MySQL.

---

## Grundläggande filstruktur (Laravel)

```
projekt/
├── app/              # Applikationskod — modeller, controllers, providers
├── bootstrap/        # Applikationsstart och cache
├── config/           # Konfigurationsfiler
├── database/         # Migrationer, seeders och factories
├── public/           # Webbrot — index.php, CSS, JS, bilder
├── resources/        # Vyer (Blade), obehandlad CSS/JS
├── routes/           # Routedefinitioner (web.php, console.php m.fl.)
├── storage/          # Loggar, cachade vyer, uppladdade filer
├── tests/            # Automatiserade tester (Unit och Feature)
├── vendor/           # Composer-beroenden (genereras, committas ej)
├── artisan           # Laravel CLI-verktyg
├── composer.json     # PHP-beroenden och projektmeta
└── phpunit.xml       # Testkonfiguration
```

---

## Filbeskrivningar

### `Dockerfile`

Bygger PHP/Apache-imagen som kör Laravel.

- Utgår från `php:8.4-apache`
- Installerar systemberoenden (git, zip, libpng m.fl.) och PHP-tillägg (pdo_mysql, mbstring, gd, zip m.fl.)
- Aktiverar Apache `mod_rewrite` och driftsätter en ren VirtualHost-konfig via `docker/apache.conf`
- Installerar Composer och kör `composer install` på projektets egna `composer.json`/`composer.lock`
- `vendor/` byggs in i imagen och monteras **aldrig** som volym — detta ger full native I/O-prestanda på Windows, macOS och Linux
- Genererar `APP_KEY` vid build-tid (kan överridas via `.env` vid runtime)
- Startar via `docker/entrypoint.sh`

### `docker/apache.conf`

Apache VirtualHost-konfig som pekar DocumentRoot mot Laravels `public/`-mapp och sätter `AllowOverride All` så att Laravels `.htaccess` (pretty URLs) fungerar korrekt.

### `docker/entrypoint.sh`

Körs automatiskt varje gång `app`-containern startar:

1. Hanterar tomt `APP_KEY` (faller tillbaka på build-time-nyckeln)
2. Skapar saknade `storage/`-undermappar (viktigt vid fresh clone)
3. Sätter rättigheter på bind-monterade mappar
4. Väntar tills MySQL är redo att ta emot anslutningar
5. Kör `php artisan migrate --force` automatiskt
6. Startar Apache

### `docker-compose.yml`

Definierar tre tjänster:

**`app`** — Laravel/Apache-containern
- Bygger imagen från `Dockerfile`
- Exponerar port definierad i `.env` (`APP_PORT`) → port 80 i containern
- Monterar källkodsmapparna för live-redigering utan rebuild:
  - `app/`, `config/`, `database/`, `routes/`, `resources/`, `public/`, `storage/`, `bootstrap/app.php`, `bootstrap/providers.php`
- `vendor/` monteras **inte** (finns i imagen) — eliminerar bind-mount-fördröjning på Windows/macOS
- Väntar på att `db` är fullt redo (`service_healthy`) innan containern startar

**`db`** — MySQL 8.0-containern
- Läser databasinställningar från `.env`
- Har en healthcheck så övriga tjänster vet när databasen faktiskt är redo
- Sparar databasdata i en namngiven volym (`dbdata`) som överlever omstarter

**`phpmyadmin`** — Webbaserat databashanteringsgränssnitt
- Tillgänglig på `http://localhost:8080`
- Kopplar automatiskt upp mot `db`-tjänsten

### `.env`

Konfigurerar både Laravel och Docker-miljön (läses av `docker-compose.yml`):

| Variabel | Beskrivning |
|---|---|
| `APP_NAME` | Applikationsnamn |
| `APP_ENV` | Miljö (`local` / `production`) |
| `APP_KEY` | Krypteringsnyckel — lämna tom lokalt (byggs in i imagen) |
| `APP_DEBUG` | Visa detaljerade felmeddelanden (`true` / `false`) |
| `APP_URL` | Publik URL till applikationen |
| `APP_PORT` | Port applikationen nås på lokalt (standard: `8000`) |
| `SESSION_DRIVER` | Sessionslagring (`file` för lokal miljö) |
| `DB_HOST` | Databashost — ska vara `db` i Docker, `127.0.0.1` på webhotell |
| `DB_PORT` | Port MySQL exponeras på (standard: `3306`) |
| `DB_DATABASE` | Databasnamn |
| `DB_USERNAME` | Databasanvändare |
| `DB_PASSWORD` | Databaslösenord |
| `DB_ROOT_PASSWORD` | MySQL root-lösenord (används av Docker-containern) |

> **OBS:** Commita aldrig `.env` med riktiga lösenord till versionshantering.

### `.env.example`

Mall med alla nödvändiga variabler (inga hemligheter). Används som utgångspunkt för `.env` — lokalt och på webhotell.

### `.dockerignore`

Talar om för Docker vilka filer som ska uteslutas från byggkontexten. Håller imagen liten och säker: exkluderar `.env`, `vendor/`, `.git/`, genererade caches m.m.

---

## A) Lokal utveckling (Docker)

### Krav

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installerat och igång

### Steg 1 — Klona projektet

```bash
git clone <repo-url>
cd <projektmapp>
```

### Steg 2 — Skapa miljöfil

Kopiera exempelfilen och fyll i valfria värden (eller behåll standardvärdena för lokal utveckling):

```bash
copy .env.example .env
```

Öppna `.env` och justera vid behov:

```
APP_PORT=8000          # Port applikationen nås på lokalt
DB_PASSWORD=secret     # Välj ett lösenord
DB_ROOT_PASSWORD=root
```

> `APP_KEY` kan lämnas tom — imagen genererar en nyckel automatiskt vid byggning.
> Sätt ett eget värde om du vill att sessionerna ska överleva en rebuild:
> ```bash
> docker compose run --rm app php artisan key:generate --show
> ```
> Kopiera sedan det utskrivna värdet till `APP_KEY=` i `.env`.

### Steg 3 — Bygg och starta applikationen

```bash
docker compose up -d --build
```

Detta bygger imagen och startar `app`-, `db`- och `phpmyadmin`-containrarna i bakgrunden.  
Första bygget tar några minuter.

Migrationer körs **automatiskt** när containern startar — inget manuellt steg krävs.

> Vid rebuild nollställs inte databasdata — det sköts av den namngivna volymen `dbdata`.
> Vill du börja om från scratch: `docker compose down -v` (tar bort volymen).

### Steg 4 — Öppna i webbläsaren

| Tjänst | URL |
|---|---|
| Applikation | `http://localhost:8000` |
| phpMyAdmin | `http://localhost:8080` |

### Övriga kommandon

```bash
# Stoppa containrarna
docker compose down

# Stoppa och ta bort databasvolymen (nollställer databasen)
docker compose down -v

# Se applikationsloggar
docker exec laravel_app tail -f /var/www/html/storage/logs/laravel.log

# Öppna ett skal inuti containern
docker exec -it laravel_app bash

# Kör en enskild Artisan-kommando
docker exec laravel_app php artisan <kommando>
```

---

## B) Driftsättning på webhotell

### Krav

- PHP 8.2 eller senare med tilläggen `pdo_mysql`, `mbstring`, `gd`, `zip`, `bcmath`
- Composer tillgänglig via SSH
- MySQL-databas med tillhörande användare
- SSH-åtkomst (rekommenderas) eller FTP

### Steg 1 — Klona eller ladda upp filerna

Via SSH:

```bash
git clone <repo-url>
cd <projektmapp>
```

Via FTP: ladda upp alla filer **utom** `vendor/`, `.env`, `Dockerfile`, `docker-compose.yml` och `docker/`.

### Steg 2 — Installera beroenden

```bash
composer install --no-dev --optimize-autoloader
```

### Steg 3 — Skapa och konfigurera `.env`

```bash
cp .env.example .env
```

Öppna `.env` och fyll i produktionsvärden:

```
APP_ENV=production
APP_DEBUG=false
APP_URL=https://din-domän.se

DB_HOST=127.0.0.1
DB_DATABASE=ditt_databasnamn
DB_USERNAME=din_databasanvändare
DB_PASSWORD=ditt_lösenord
```

### Steg 4 — Generera applikationsnyckel

```bash
php artisan key:generate
```

### Steg 5 — Kör databasmigrationer

```bash
php artisan migrate --force
```

### Steg 6 — Sätt rättigheter

```bash
chmod -R 775 storage bootstrap/cache
chown -R www-data:www-data storage bootstrap/cache
```

> På delade webhotell kan `chown` saknas — `chmod 775` brukar räcka.

### Steg 7 — Peka webbrotens DocumentRoot mot `public/`

I webbhotellets kontrollpanel: ange `public/` (eller `public_html/` om så krävs) som webbrot för domänen.  
Om du inte kan ändra webrooten, lägg en `.htaccess` i rooten:

```apache
RewriteEngine on
RewriteCond %{REQUEST_URI} !^/public/
RewriteRule ^(.*)$ /public/$1 [L,QSA]
```

### Steg 8 — Optimera för produktion (valfritt)

```bash
php artisan config:cache
php artisan route:cache
php artisan view:cache
```

---

## Lägga till en ny resurs

Exempel: lägga till en resurs `Product` med fälten `name` och `price`.

### Steg 1 — Skapa migration, modell och controller

```bash
docker exec laravel_app php artisan make:model Product -mc
```

Skapar tre filer:
- `database/migrations/XXXX_create_products_table.php`
- `app/Models/Product.php`
- `app/Http/Controllers/ProductController.php`

### Steg 2 — Definiera tabellstrukturen i migrationen

Öppna den nyskapade filen i `database/migrations/` och fyll i `up()`:

```php
Schema::create('products', function (Blueprint $table) {
    $table->id();
    $table->string('name');
    $table->decimal('price', 8, 2);
    $table->timestamps();
});
```

### Steg 3 — Kör migrationen

```bash
docker exec laravel_app php artisan migrate
```

> Migrationen körs även automatiskt nästa gång containern startas om.

### Steg 4 — Uppdatera modellen

I `app/Models/Product.php`, lägg till fillable-fält:

```php
protected $fillable = ['name', 'price'];
```

### Steg 5 — Lägg till logik i controllern

I `app/Http/Controllers/ProductController.php`:

```php
use App\Models\Product;

public function index()
{
    $products = Product::all();
    return view('products.index', compact('products'));
}
```

### Steg 6 — Skapa en Blade-vy

Skapa filen `resources/views/products/index.blade.php`:

```blade
@extends('layouts.app')

@section('title', 'Produkter')

@section('content')
    <h1>Produkter</h1>
    @foreach($products as $product)
        <p>{{ $product->name }} — {{ $product->price }} kr</p>
    @endforeach
@endsection
```

### Steg 7 — Lägg till en route

I `routes/web.php`:

```php
use App\Http\Controllers\ProductController;

Route::get('/products', [ProductController::class, 'index']);
```

Resursen är nu tillgänglig på `http://localhost:8000/products`.

---

## Aktivera SCSS-stöd

Projektet använder för närvarande plain CSS (`public/css/app.css`). Följ dessa steg för att byta till SCSS med Vite.

### Steg 1 — Skapa `package.json`

Skapa filen i projektroten:

```json
{
  "private": true,
  "scripts": {
    "dev": "vite",
    "build": "vite build"
  },
  "devDependencies": {
    "laravel-vite-plugin": "^1.0",
    "sass": "^1.0",
    "vite": "^6.0"
  }
}
```

### Steg 2 — Skapa `vite.config.js`

Skapa filen i projektroten:

```js
import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';

export default defineConfig({
    plugins: [
        laravel({
            input: ['resources/scss/app.scss'],
            refresh: true,
        }),
    ],
});
```

### Steg 3 — Flytta CSS till SCSS

Skapa mappen `resources/scss/` och flytta innehållet från `public/css/app.css`:

```bash
# Skapa mappen och flytta filen
mkdir resources/scss
move public\css\app.css resources\scss\app.scss
```

Döp om filen till `app.scss` och börja använda SCSS-syntax vid behov.

### Steg 4 — Uppdatera layoutvyn

I `resources/views/layouts/app.blade.php`, ersätt `<link>`-taggen med Vites direktiv:

```diff
- <link rel="stylesheet" href="/css/app.css">
+ @vite('resources/scss/app.scss')
```

### Steg 5 — Uppdatera `Dockerfile`

Lägg till Node.js bland systemberoenden och bygg assets vid image-bygget:

```diff
  RUN apt-get update && apt-get install -y \
      git curl zip unzip \
      libpng-dev libonig-dev libxml2-dev libzip-dev \
+     nodejs npm \
      && rm -rf /var/lib/apt/lists/*
```

Och efter `COPY . .`:

```diff
  RUN composer dump-autoload --optimize
+ RUN npm ci && npm run build
```

### Steg 6 — Bygg om Docker-imagen

```bash
docker compose up --build
```

> `node_modules/` är redan undantaget i `.dockerignore` och `.gitignore` — inget behöver ändras där.
