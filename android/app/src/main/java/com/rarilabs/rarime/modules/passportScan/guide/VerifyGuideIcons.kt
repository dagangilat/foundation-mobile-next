package com.rarilabs.rarime.modules.passportScan.guide

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.addPathNodes
import androidx.compose.ui.unit.dp

/**
 * The stroke icons the verify-guide mockups use (Lucide, 24x24 viewport),
 * built in code rather than added as drawables. Stroked in black; `Icon`
 * tints them at the call site, like the ic_fnd_* drawables.
 */
internal object VerifyIcons {
    val Check: ImageVector by lazy {
        lucideIcon("Check", listOf("M20 6L9 17l-5-5"))
    }

    /** The heavier check inside filled circles (guide markers, check rows). */
    val CheckBold: ImageVector by lazy {
        lucideIcon("CheckBold", listOf("M20 6L9 17l-5-5"), strokeWidth = 3f)
    }

    /** The large check on the confirmation screens. */
    val CheckLarge: ImageVector by lazy {
        lucideIcon("CheckLarge", listOf("M20 6L9 17l-5-5"), strokeWidth = 2.5f)
    }

    val Lock: ImageVector by lazy {
        lucideIcon(
            "Lock",
            listOf(
                "M5 11h14a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-7a2 2 0 0 1 2-2z",
                "M7 11V7a5 5 0 0 1 10 0v4",
            )
        )
    }

    val BookOpen: ImageVector by lazy {
        lucideIcon(
            "BookOpen",
            listOf(
                "M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z",
                "M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z",
            )
        )
    }

    val Sun: ImageVector by lazy {
        lucideIcon(
            "Sun",
            listOf(
                "M8 12a4 4 0 1 0 8 0a4 4 0 1 0-8 0z",
                "M12 2v2",
                "M12 20v2",
                "M4.93 4.93l1.41 1.41",
                "M17.66 17.66l1.41 1.41",
                "M2 12h2",
                "M20 12h2",
                "M6.34 17.66l-1.41 1.41",
                "M19.07 4.93l-1.41 1.41",
            )
        )
    }

    val MoveHorizontal: ImageVector by lazy {
        lucideIcon(
            "MoveHorizontal",
            listOf(
                "M21 12H3",
                "M6 9l-3 3 3 3",
                "M18 9l3 3-3 3",
            )
        )
    }

    /** Viewfinder corners around a lens: "Open the camera". */
    val ScanCamera: ImageVector by lazy {
        lucideIcon(
            "ScanCamera",
            listOf(
                "M3 7V5a2 2 0 0 1 2-2h2",
                "M17 3h2a2 2 0 0 1 2 2v2",
                "M21 17v2a2 2 0 0 1-2 2h-2",
                "M7 21H5a2 2 0 0 1-2-2v-2",
                "M9 12a3 3 0 1 0 6 0a3 3 0 1 0-6 0z",
            )
        )
    }

    val Smartphone: ImageVector by lazy {
        lucideIcon(
            "Smartphone",
            listOf(
                "M7 2h10a2 2 0 0 1 2 2v16a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2z",
                "M12 18h0.01",
            )
        )
    }

    val Chip: ImageVector by lazy {
        lucideIcon(
            "Chip",
            listOf(
                "M7 5h10a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2z",
                "M9 9h6v6H9z",
                "M9 2v3",
                "M15 2v3",
                "M9 19v3",
                "M15 19v3",
                "M2 9h3",
                "M2 15h3",
                "M19 9h3",
                "M19 15h3",
            )
        )
    }

    val Plug: ImageVector by lazy {
        lucideIcon(
            "Plug",
            listOf(
                "M12 22v-5",
                "M9 8V2",
                "M15 8V2",
                "M18 8v5a4 4 0 0 1-4 4h-4a4 4 0 0 1-4-4V8z",
            )
        )
    }

    /** Contactless waves: "Start chip scan". */
    val Nfc: ImageVector by lazy {
        lucideIcon(
            "Nfc",
            listOf(
                "M6 8.32a7.43 7.43 0 0 1 0 7.36",
                "M9.46 6.21a11.76 11.76 0 0 1 0 11.58",
                "M12.91 4.1a15.91 15.91 0 0 1 0.01 15.8",
                "M16.37 2a20.16 20.16 0 0 1 0 20",
            )
        )
    }
}

private fun lucideIcon(
    name: String,
    paths: List<String>,
    strokeWidth: Float = 2f,
): ImageVector {
    val builder = ImageVector.Builder(
        name = name,
        defaultWidth = 24.dp,
        defaultHeight = 24.dp,
        viewportWidth = 24f,
        viewportHeight = 24f,
    )
    paths.forEach { pathData ->
        builder.addPath(
            pathData = addPathNodes(pathData),
            fill = null,
            stroke = SolidColor(Color.Black),
            strokeLineWidth = strokeWidth,
            strokeLineCap = StrokeCap.Round,
            strokeLineJoin = StrokeJoin.Round,
        )
    }
    return builder.build()
}
