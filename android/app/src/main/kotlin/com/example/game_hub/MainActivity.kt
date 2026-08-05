package com.example.game_hub

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Registers the native PlatformView that embeds a Godot 4.4 engine
        // instance for the Football game (see GodotEmbedView.kt). The Dart
        // side creates it via AndroidView(viewType: 'godot_embed_view').
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory("godot_embed_view", GodotEmbedViewFactory())
    }
}
