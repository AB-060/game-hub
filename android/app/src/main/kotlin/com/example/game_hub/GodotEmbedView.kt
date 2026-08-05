package com.example.game_hub

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView
import io.flutter.plugin.platform.PlatformView

/**
 * Hosts a Godot 4.4 engine instance inside a Flutter [PlatformView].
 *
 * Godot's Android library (built from `soccer-course/` in the Godot 4.4
 * Editor via Project > Export > Android > "Export as .aar") exposes an
 * `org.godotengine.godot.Godot` class that owns the engine's native
 * lifecycle (onCreate/onStart/onResume/onPause/onStop/onDestroy) and a
 * `GodotView`/render surface that must be attached to a ViewGroup.
 * Historically Godot's Android embedding samples wire `Godot` up through a
 * `GodotFragment`/`GodotActivity`, which assumes a hosting Activity or
 * Fragment. A raw Flutter `PlatformView` gives us neither, so this class
 * attaches to `Godot` at the lower level it exposes for embedding: creating
 * a `Godot` instance directly, driving it with the `Context`/`Activity`
 * available from the Flutter engine's binding, and inserting its content
 * view into this class's own [FrameLayout].
 *
 * // TODO(godot-aar): This file is written from the publicly documented
 * // shape of Godot 4.4's Android embedding API as of this writing, but it
 * // has NOT been compiled or run against the real godot-lib.aar (Godot
 * // isn't available in this environment). Once the AAR is added under
 * // android/app/libs/godot-lib.aar and the Gradle dependency in
 * // android/app/build.gradle.kts is uncommented, verify against the AAR's
 * // actual Javadoc/sources for:
 * //   - The exact constructor/factory for `org.godotengine.godot.Godot`
 * //     (some 4.x versions expose `Godot(Context)`, others require it be
 * //     created via `Godot.getInstance()` or instantiated as a Fragment).
 * //   - Whether `Godot` needs a `GodotHost` implementation passed in (an
 * //     interface the hosting Activity/Fragment normally implements) and
 * //     what subset of its methods are mandatory vs. no-op-able here.
 * //   - The correct lifecycle call sequence (`onCreate`, `onGodotSetupCompleted`,
 * //     `onGodotMainLoopStarted`, `onDestroy`) and which of these are safe
 * //     to invoke without a hosting Activity/Fragment lifecycle.
 * //   - Whether the engine's render view is obtained via `godot.getView()`
 * //     / `godot.onCreateView(...)` or another accessor in this version.
 * // Treat everything below the placeholder as a best-effort skeleton to
 * // adapt once the real API surface can be inspected.
 */
class GodotEmbedView(
    context: Context,
    viewId: Int,
    creationParams: Map<String?, Any?>?,
) : PlatformView {

    private val container: FrameLayout = FrameLayout(context)

    // Held once the real Godot engine is wired in; null while the AAR is
    // absent, in which case we show an honest placeholder instead of
    // silently pretending the game is running.
    private var godotContentView: View? = null

    init {
        val projectIdentifier = creationParams?.get("projectPath") as? String

        // TODO(godot-aar): Replace this block with real engine startup once
        // godot-lib.aar is present, e.g. (illustrative, unverified shape):
        //
        //   val godot = org.godotengine.godot.Godot(context)
        //   godot.onCreate(hostActivity) // or the applicable lifecycle entry
        //   val engineView = godot.onCreateView(hostActivity)
        //   container.addView(engineView, FrameLayout.LayoutParams(
        //       FrameLayout.LayoutParams.MATCH_PARENT,
        //       FrameLayout.LayoutParams.MATCH_PARENT,
        //   ))
        //   godotContentView = engineView
        //
        // Until then, fail honestly instead of faking a running game.
        val placeholder = TextView(context).apply {
            text = "Godot Android library (godot-lib.aar) is not present.\n" +
                "See lib/games/football/soccer-course/EXPORT.md for how to " +
                "export it from the Godot 4.4 Editor and wire it into " +
                "android/app/build.gradle.kts.\n" +
                "projectIdentifier=$projectIdentifier"
            setPadding(32, 32, 32, 32)
        }
        container.addView(placeholder)
    }

    override fun getView(): View = container

    override fun dispose() {
        // TODO(godot-aar): once wired to a real `Godot` instance, forward
        // dispose() into its lifecycle, roughly:
        //   godot?.onDestroy(hostActivity)
        godotContentView = null
        container.removeAllViews()
    }
}
