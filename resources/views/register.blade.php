@extends('layouts.app')

@section('title', 'Registrera konto')

@section('content')
    <h1>Registrera konto</h1>

    @if(session('success'))
        <p class="alert-success">{{ session('success') }}</p>
    @endif

    <form method="POST" action="/register">
        @csrf

        <label for="username">Användarnamn</label>
        <input type="text" id="username" name="username"
               value="{{ old('username') }}" required autofocus>
        @error('username')
            <p class="alert-error">{{ $message }}</p>
        @enderror

        <label for="password">Lösenord</label>
        <input type="password" id="password" name="password" required>
        @error('password')
            <p class="alert-error">{{ $message }}</p>
        @enderror

        <label for="password_confirmation">Bekräfta lösenord</label>
        <input type="password" id="password_confirmation" name="password_confirmation" required>

        <button type="submit">Registrera</button>
    </form>
@endsection
