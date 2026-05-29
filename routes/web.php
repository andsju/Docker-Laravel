<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\RegisterController;

// Startsida
Route::get('/', function () {
    return view('home');
});

// Exempel: GET med parameter
Route::get('/hello/{name}', function (string $name) {
    return "Hej, $name!";
});

// Registrering
Route::get('/register', [RegisterController::class, 'create']);
Route::post('/register', [RegisterController::class, 'store']);
