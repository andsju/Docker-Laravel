<?php

namespace App\Http\Controllers;

use App\Models\Member;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class RegisterController extends Controller
{
    public function create()
    {
        return view('register');
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'username' => 'required|string|max:255|unique:members',
            'password' => 'required|string|min:8|confirmed',
        ]);

        Member::create([
            'username' => $validated['username'],
            'password' => Hash::make($validated['password']),
        ]);

        return redirect('/register')->with('success', 'Konto skapat!');
    }
}
