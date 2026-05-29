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

---

## Installation och uppstart

### Krav

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installerat och igång

### Steg 1 — Klona projektet

```bash
git clone <repo-url>
cd <projektmapp>
```

### Steg 2 — Starta applikationen

```bash
docker-compose up -d --build
```

Detta bygger imagen och startar både `app`- och `db`-containrarna i bakgrunden.  
Första bygget tar några minuter.

### Steg 3 — Kör databasmigrationer

Migrationer måste köras efter docker --build. MySQL-datan nollställs.

```bash
docker exec laravel_app php artisan migrate --force
```

Skapar alla tabeller i databasen.

### Steg 4 — Öppna i webbläsaren

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
