# Laravel Docker-projekt

En Laravel-applikation som körs i Docker med Apache och MySQL.

---

## Filbeskrivningar

### `Dockerfile`

Bygger PHP/Apache-imagen som kör Laravel.

- Utgår från `php:8.4-apache`
- Installerar systemberoenden (git, zip, libpng m.fl.) och PHP-tillägg (pdo_mysql, mbstring, gd, zip m.fl.)
- Aktiverar Apache `mod_rewrite` (krävs för Laravels routing)
- Installerar Composer och scaffoldar ett nytt Laravel-projekt med `composer create-project`
- Kopierar in `app/.env` (databasinställningar) och genererar `APP_KEY` automatiskt
- Pekar Apaches DocumentRoot till Laravels `public/`-mapp

### `docker-compose.yml`

Definierar två tjänster:

**`app`** — Laravel/Apache-containern
- Bygger imagen från `Dockerfile`
- Exponerar port definierad i `.env` (`APP_PORT`) → port 80 i containern
- Monterar lokala mappar som volymer så att kodändringar syns direkt utan rebuild:
  - `routes/`, `resources/views/`, `app/`, `database/migrations/`, `public/`

**`db`** — MySQL 8.0-containern
- Läser databasinställningar från `.env`
- Sparar databasdata i en namngiven volym (`dbdata`) som överlever omstarter

### `.env`

Konfigurerar Docker-miljön (läses av `docker-compose.yml`):

| Variabel | Beskrivning |
|---|---|
| `APP_PORT` | Port applikationen nås på (standard: 8000) |
| `DB_PORT` | Port MySQL exponeras på (standard: 3306) |
| `DB_DATABASE` | Databasnamn |
| `DB_USERNAME` | Databasanvändare |
| `DB_PASSWORD` | Databaslösenord |
| `DB_ROOT_PASSWORD` | MySQL root-lösenord |

> **OBS:** Commita aldrig `.env` med riktiga lösenord till versionshantering.

### `.env.example`

Mall för Laravel-konfiguration. Kopieras till `.env` vid driftsättning på webhotell och fylls i med riktiga värden.

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
APP_PORT=8000        # Port applikationen nås på lokalt
DB_PASSWORD=secret   # Välj ett lösenord
DB_ROOT_PASSWORD=root
```

### Steg 3 — Starta applikationen

```bash
docker-compose up -d --build
```

Detta bygger imagen och startar både `app`- och `db`-containrarna i bakgrunden.  
Första bygget tar några minuter.

### Steg 4 — Kör databasmigrationer

Migrationer måste köras efter `--build`. MySQL-datan nollställs vid rebuild.

```bash
docker exec laravel_app php artisan migrate --force
```

### Steg 5 — Öppna i webbläsaren

```
http://localhost:8000
```

### Övriga kommandon

```bash
# Stoppa containrarna
docker-compose down

# Se loggar
docker exec laravel_app tail -f /var/www/html/storage/logs/laravel.log

# Öppna ett skal inuti containern
docker exec -it laravel_app bash
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

Via FTP: ladda upp alla filer **utom** `vendor/`, `.env`, `Dockerfile` och `docker-compose.yml`.

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
