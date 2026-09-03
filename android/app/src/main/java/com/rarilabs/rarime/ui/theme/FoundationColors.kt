package com.rarilabs.rarime.ui.theme

import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.runtime.structuralEqualityPolicy
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color

@Stable
class FoundationColors(
    // primary
    primaryDarker: Color,
    primaryDark: Color,
    primaryMain: Color,
    primaryLight: Color,
    primaryLighter: Color,

    // secondary
    secondaryDarker: Color,
    secondaryDark: Color,
    secondaryMain: Color,
    secondaryLight: Color,
    secondaryLighter: Color,

    // success
    successDarker: Color,
    successDark: Color,
    successMain: Color,
    successLight: Color,
    successLighter: Color,

    // info
    infoDarker: Color,
    infoDark: Color,
    infoMain: Color,
    infoLight: Color,
    infoLighter: Color,

    // error
    errorDarker: Color,
    errorDark: Color,
    errorMain: Color,
    errorLight: Color,
    errorLighter: Color,

    // warning
    warningBase: Color,
    warningDarker: Color,
    warningDark: Color,
    warningMain: Color,
    warningLight: Color,
    warningLighter: Color,

    // text
    textPrimary: Color,
    textSecondary: Color,
    textPlaceholder: Color,
    textDisabled: Color,

    // component
    componentPrimary: Color,
    componentHovered: Color,
    componentPressed: Color,
    componentSelected: Color,
    componentDisabled: Color,

    // background
    backgroundPrimary: Color,
    backgroundContainer: Color,
    backgroundBlur: Color,
    backgroundSurface1: Color,
    backgroundSurface2: Color,
    backgroundPure: Color,

    // base
    baseBlack: Color,

    baseBlackOp50: Color,
    baseBlackOp40: Color,
    baseWhite: Color,

    // inverted
    invertedDark: Color,
    invertedLight: Color,
    inverted: Color,


    // additional
    gradient1: Brush,
    gradient2: Brush,
    gradient3: Brush,
    gradient4: Brush,
    gradient5: Brush,
    gradient6: Brush,
    gradient7: Brush,
    gradient8: Brush,
    gradient9: Brush,
    gradient10: Brush,
    gradient11: Brush,
    gradient12: Brush,
    gradient13: Brush,
    gradient14: Brush,
    gradient15: Brush,



    additionalGreen: Color,
    hiddenPrizeAccent: Color,
    hiddenPrizeBackground: Color,


    welcomeAccent1: Color,
    welcomeAccent2: Color,
    welcomeAccent3: Color,
    welcomeAccent4: Color,

    ) {
    var primaryDarker by mutableStateOf(primaryDarker, structuralEqualityPolicy())
        internal set
    var primaryDark by mutableStateOf(primaryDark, structuralEqualityPolicy())
        internal set
    var primaryMain by mutableStateOf(primaryMain, structuralEqualityPolicy())
        internal set
    var primaryLight by mutableStateOf(primaryLight, structuralEqualityPolicy())
        internal set
    var primaryLighter by mutableStateOf(primaryLighter, structuralEqualityPolicy())
        internal set
    var secondaryDarker by mutableStateOf(secondaryDarker, structuralEqualityPolicy())
        internal set
    var secondaryDark by mutableStateOf(secondaryDark, structuralEqualityPolicy())
        internal set
    var secondaryMain by mutableStateOf(secondaryMain, structuralEqualityPolicy())
        internal set
    var secondaryLight by mutableStateOf(secondaryLight, structuralEqualityPolicy())
        internal set
    var secondaryLighter by mutableStateOf(secondaryLighter, structuralEqualityPolicy())
        internal set
    var successDarker by mutableStateOf(successDarker, structuralEqualityPolicy())
        internal set
    var successDark by mutableStateOf(successDark, structuralEqualityPolicy())
        internal set
    var successMain by mutableStateOf(successMain, structuralEqualityPolicy())
        internal set
    var successLight by mutableStateOf(successLight, structuralEqualityPolicy())
        internal set
    var successLighter by mutableStateOf(successLighter, structuralEqualityPolicy())
        internal set
    var infoDarker by mutableStateOf(infoDarker, structuralEqualityPolicy())
        internal set
    var infoDark by mutableStateOf(infoDark, structuralEqualityPolicy())
        internal set
    var infoMain by mutableStateOf(infoMain, structuralEqualityPolicy())
        internal set
    var infoLight by mutableStateOf(infoLight, structuralEqualityPolicy())
        internal set
    var infoLighter by mutableStateOf(infoLighter, structuralEqualityPolicy())
        internal set
    var errorDarker by mutableStateOf(errorDarker, structuralEqualityPolicy())
        internal set
    var errorDark by mutableStateOf(errorDark, structuralEqualityPolicy())
        internal set
    var errorMain by mutableStateOf(errorMain, structuralEqualityPolicy())
        internal set
    var errorLight by mutableStateOf(errorLight, structuralEqualityPolicy())
        internal set
    var errorLighter by mutableStateOf(errorLighter, structuralEqualityPolicy())
        internal set
    var warningDarker by mutableStateOf(warningDarker, structuralEqualityPolicy())
        internal set
    var warningBase by mutableStateOf(warningBase, structuralEqualityPolicy())
        internal set
    var warningDark by mutableStateOf(warningDark, structuralEqualityPolicy())
        internal set
    var warningMain by mutableStateOf(warningMain, structuralEqualityPolicy())
        internal set
    var warningLight by mutableStateOf(warningLight, structuralEqualityPolicy())
        internal set
    var warningLighter by mutableStateOf(warningLighter, structuralEqualityPolicy())
        internal set
    var textPrimary by mutableStateOf(textPrimary, structuralEqualityPolicy())
        internal set
    var textSecondary by mutableStateOf(textSecondary, structuralEqualityPolicy())
        internal set
    var textPlaceholder by mutableStateOf(textPlaceholder, structuralEqualityPolicy())
        internal set
    var textDisabled by mutableStateOf(textDisabled, structuralEqualityPolicy())
        internal set
    var componentPrimary by mutableStateOf(componentPrimary, structuralEqualityPolicy())
        internal set
    var componentHovered by mutableStateOf(componentHovered, structuralEqualityPolicy())
        internal set
    var componentPressed by mutableStateOf(componentPressed, structuralEqualityPolicy())
        internal set
    var componentSelected by mutableStateOf(componentSelected, structuralEqualityPolicy())
        internal set
    var componentDisabled by mutableStateOf(componentDisabled, structuralEqualityPolicy())
        internal set
    var backgroundPrimary by mutableStateOf(backgroundPrimary, structuralEqualityPolicy())
        internal set
    var backgroundBlur by mutableStateOf(backgroundBlur, structuralEqualityPolicy())
        internal set
    var backgroundSurface1 by mutableStateOf(backgroundSurface1, structuralEqualityPolicy())
        internal set
    var backgroundSurface2 by mutableStateOf(backgroundSurface2, structuralEqualityPolicy())
        internal set
    var backgroundContainer by mutableStateOf(backgroundPrimary, structuralEqualityPolicy())
        internal set
    var backgroundPure by mutableStateOf(backgroundPure, structuralEqualityPolicy())
        internal set
    var baseBlack by mutableStateOf(baseBlack, structuralEqualityPolicy())
        internal set

    var baseBlackOp50 by mutableStateOf(baseBlackOp50, structuralEqualityPolicy())
        internal set

    var baseBlackOp40 by mutableStateOf(baseBlackOp40, structuralEqualityPolicy())
        internal set
    var baseWhite by mutableStateOf(baseWhite, structuralEqualityPolicy())
        internal set
    var invertedDark by mutableStateOf(invertedDark, structuralEqualityPolicy())
        internal set
    var invertedLight by mutableStateOf(invertedLight, structuralEqualityPolicy())
        internal set
    var gradient1 by mutableStateOf(gradient1, structuralEqualityPolicy())
        internal set

    var gradient2 by mutableStateOf(gradient2, structuralEqualityPolicy())
        internal set

    var gradient3 by mutableStateOf(gradient3, structuralEqualityPolicy())
        internal set

    var gradient4 by mutableStateOf(gradient4, structuralEqualityPolicy())
        internal set

    var gradient5 by mutableStateOf(gradient5, structuralEqualityPolicy())
        internal set

    var gradient6 by mutableStateOf(gradient6, structuralEqualityPolicy())
        internal set

    var gradient7 by mutableStateOf(gradient7, structuralEqualityPolicy())
        internal set
    var gradient8 by mutableStateOf(gradient8, structuralEqualityPolicy())
        internal set
    var gradient9 by mutableStateOf(gradient9, structuralEqualityPolicy())
        internal set
    var gradient10 by mutableStateOf(gradient10, structuralEqualityPolicy())
        internal set
    var gradient11 by mutableStateOf(gradient11, structuralEqualityPolicy())
        internal set
    var gradient12 by mutableStateOf(gradient12, structuralEqualityPolicy())
        internal set
    var gradient13 by mutableStateOf(gradient13, structuralEqualityPolicy())
        internal set

    var gradient14 by mutableStateOf(gradient14, structuralEqualityPolicy())
        internal set
    var gradient15 by mutableStateOf(gradient15, structuralEqualityPolicy())
        internal set

    var inverted by mutableStateOf(inverted, structuralEqualityPolicy())
        internal set

    var additionalGreen by mutableStateOf(additionalGreen, structuralEqualityPolicy())
        internal set

    var hiddenPrizeAccent by mutableStateOf(hiddenPrizeAccent, structuralEqualityPolicy())

    var hiddenPrizeBackground by mutableStateOf(hiddenPrizeBackground, structuralEqualityPolicy())


    var welcomeAccent1 by mutableStateOf(welcomeAccent1, structuralEqualityPolicy())
    var welcomeAccent2 by mutableStateOf(welcomeAccent2, structuralEqualityPolicy())
    var welcomeAccent3 by mutableStateOf(welcomeAccent3, structuralEqualityPolicy())
    var welcomeAccent4 by mutableStateOf(welcomeAccent4, structuralEqualityPolicy())


    fun copy(
        primaryDarker: Color = this.primaryDarker,
        primaryDark: Color = this.primaryDark,
        primaryMain: Color = this.primaryMain,
        primaryLight: Color = this.primaryLight,
        primaryLighter: Color = this.primaryLighter,
        secondaryDarker: Color = this.secondaryDarker,
        secondaryDark: Color = this.secondaryDark,
        secondaryMain: Color = this.secondaryMain,
        secondaryLight: Color = this.secondaryLight,
        secondaryLighter: Color = this.secondaryLighter,
        successDarker: Color = this.successDarker,
        successDark: Color = this.successDark,
        successMain: Color = this.successMain,
        successLight: Color = this.successLight,
        successLighter: Color = this.successLighter,
        infoDarker: Color = this.infoDarker,
        infoDark: Color = this.infoDark,
        infoMain: Color = this.infoMain,
        infoLight: Color = this.infoLight,
        infoLighter: Color = this.infoLighter,
        errorDarker: Color = this.errorDarker,
        errorDark: Color = this.errorDark,
        errorMain: Color = this.errorMain,
        errorLight: Color = this.errorLight,
        errorLighter: Color = this.errorLighter,
        warningBase: Color = this.warningBase,
        warningDarker: Color = this.warningDarker,
        warningDark: Color = this.warningDark,
        warningMain: Color = this.warningMain,
        warningLight: Color = this.warningLight,
        warningLighter: Color = this.warningLighter,
        textPrimary: Color = this.textPrimary,
        textSecondary: Color = this.textSecondary,
        textPlaceholder: Color = this.textPlaceholder,
        textDisabled: Color = this.textDisabled,
        componentPrimary: Color = this.componentPrimary,
        componentHovered: Color = this.componentHovered,
        componentPressed: Color = this.componentPressed,
        componentSelected: Color = this.componentSelected,
        componentDisabled: Color = this.componentDisabled,
        backgroundPrimary: Color = this.backgroundPrimary,
        backgroundPure: Color = this.backgroundPure,
        baseBlack: Color = this.baseBlack,
        baseWhite: Color = this.baseWhite,
        backgroundContainer: Color = this.backgroundContainer,
        gradient1: Brush = this.gradient1,
        gradient2: Brush = this.gradient2,
        gradient3: Brush = this.gradient3,
        gradient4: Brush = this.gradient4,
        gradient5: Brush = this.gradient5,
        gradient6: Brush = this.gradient6,
        gradient7: Brush = this.gradient7,
        gradient8: Brush = this.gradient8,
        gradient9: Brush = this.gradient9,
        gradient10: Brush = this.gradient10,
        gradient11: Brush = this.gradient11,
        gradient12: Brush = this.gradient12,
        gradient13: Brush = this.gradient13,
        gradient14: Brush = this.gradient14,
        gradient15: Brush = this.gradient15,
        invertedDark: Color = this.invertedDark,
        invertedLight: Color = this.invertedLight,
        inverted: Color = this.inverted,
        baseBlackOp40: Color = this.baseBlackOp40,
        baseBlackOp50: Color = this.baseBlackOp50,
        additionalGreen: Color = this.additionalGreen,

        backgroundBlur: Color = this.backgroundBlur,
        backgroundSurface1: Color = this.backgroundSurface1,
        backgroundSurface2: Color = this.backgroundSurface2,

        welcomeAccent1: Color = this.welcomeAccent1,
        welcomeAccent2: Color = this.welcomeAccent2,
        welcomeAccent3: Color = this.welcomeAccent3,
        welcomeAccent4: Color = this.welcomeAccent4,


        ) = FoundationColors(
        primaryDarker = primaryDarker,
        primaryDark = primaryDark,
        primaryMain = primaryMain,
        primaryLight = primaryLight,
        primaryLighter = primaryLighter,
        secondaryDarker = secondaryDarker,
        secondaryDark = secondaryDark,
        secondaryMain = secondaryMain,
        secondaryLight = secondaryLight,
        secondaryLighter = secondaryLighter,
        successDarker = successDarker,
        successDark = successDark,
        successMain = successMain,
        successLight = successLight,
        successLighter = successLighter,
        infoDarker = infoDarker,
        infoDark = infoDark,
        infoMain = infoMain,
        infoLight = infoLight,
        infoLighter = infoLighter,
        errorDarker = errorDarker,
        errorDark = errorDark,
        errorMain = errorMain,
        errorLight = errorLight,
        errorLighter = errorLighter,
        warningBase = warningBase,
        warningDarker = warningDarker,
        warningDark = warningDark,
        warningMain = warningMain,
        warningLight = warningLight,
        warningLighter = warningLighter,
        textPrimary = textPrimary,
        textSecondary = textSecondary,
        textPlaceholder = textPlaceholder,
        textDisabled = textDisabled,
        componentPrimary = componentPrimary,
        componentHovered = componentHovered,
        componentPressed = componentPressed,
        componentSelected = componentSelected,
        componentDisabled = componentDisabled,
        backgroundPrimary = backgroundPrimary,
        backgroundBlur = backgroundBlur,
        backgroundSurface1 = backgroundSurface1,
        backgroundSurface2 = backgroundSurface2,
        backgroundPure = backgroundPure,
        baseBlack = baseBlack,
        baseWhite = baseWhite,
        baseBlackOp40 = baseBlackOp40,
        baseBlackOp50 = baseBlackOp50,
        invertedDark = invertedDark,
        invertedLight = invertedLight,
        backgroundContainer = backgroundContainer,
        gradient1 = gradient1,
        gradient2 = gradient2,
        gradient3 = gradient3,
        gradient4 = gradient4,
        gradient5 = gradient5,
        gradient6 = gradient6,
        gradient7 = gradient7,
        gradient8 = gradient8,
        gradient9 = gradient9,
        gradient10 = gradient10,
        gradient11 = gradient11,
        gradient12 = gradient12,
        gradient13 = gradient13,
        gradient14 = gradient14,
        gradient15 = gradient15,
        additionalGreen = additionalGreen,
        inverted = inverted,
        hiddenPrizeAccent = hiddenPrizeAccent,
        hiddenPrizeBackground = hiddenPrizeBackground,
        welcomeAccent1 = welcomeAccent1,
        welcomeAccent2 = welcomeAccent2,
        welcomeAccent3 = welcomeAccent3,
        welcomeAccent4 = welcomeAccent4
    )

    fun updateColorsFrom(other: FoundationColors) {
        this.primaryDarker = other.primaryDarker
        this.primaryDark = other.primaryDark
        this.primaryMain = other.primaryMain
        this.primaryLight = other.primaryLight
        this.primaryLighter = other.primaryLighter
        this.secondaryDarker = other.secondaryDarker
        this.secondaryDark = other.secondaryDark
        this.secondaryMain = other.secondaryMain
        this.secondaryLight = other.secondaryLight
        this.secondaryLighter = other.secondaryLighter
        this.successDarker = other.successDarker
        this.successDark = other.successDark
        this.successMain = other.successMain
        this.successLight = other.successLight
        this.successLighter = other.successLighter
        this.infoDarker = other.infoDarker
        this.infoMain = other.infoMain
        this.infoLighter = other.infoLighter
        this.infoLight = other.infoLight
        this.errorDarker = other.errorDarker
        this.infoDarker = other.infoDarker
        this.infoMain = other.infoMain
        this.infoLighter = other.infoLighter
        this.infoLight = other.infoLight
        this.errorDark = other.errorDark
        this.errorMain = other.errorMain
        this.errorLight = other.errorLight
        this.errorLighter = other.errorLighter
        this.warningBase = other.warningBase
        this.warningDarker = other.warningDarker
        this.warningDark = other.warningDark
        this.warningMain = other.warningMain
        this.warningLight = other.warningLight
        this.warningLighter = other.warningLighter
        this.textPrimary = other.textPrimary
        this.textSecondary = other.textSecondary
        this.textPlaceholder = other.textPlaceholder
        this.textDisabled = other.textDisabled
        this.componentPrimary = other.componentPrimary
        this.componentHovered = other.componentHovered
        this.componentPressed = other.componentPressed
        this.componentSelected = other.componentSelected
        this.componentDisabled = other.componentDisabled
        this.backgroundPrimary = other.backgroundPrimary
        this.backgroundContainer = other.backgroundContainer
        this.backgroundPure = other.backgroundPure
        this.baseBlack = other.baseBlack
        this.baseWhite = other.baseWhite
        this.invertedDark = other.invertedDark
        this.invertedLight = other.invertedLight
        this.inverted = other.inverted
        this.backgroundSurface1 = other.backgroundSurface1
        this.backgroundSurface2 = other.backgroundSurface2
        this.backgroundPure = other.backgroundPure
        this.baseBlack = other.baseBlack
        this.baseWhite = other.baseWhite
        this.baseBlackOp40 = other.baseBlackOp40
        this.baseBlackOp50 = other.baseBlackOp50
        this.invertedDark = other.invertedDark
        this.invertedLight = other.invertedLight
        this.backgroundContainer = other.backgroundContainer
        this.gradient1 = other.gradient1
        this.gradient2 = other.gradient2
        this.gradient3 = other.gradient3
        this.gradient4 = other.gradient4
        this.gradient5 = other.gradient5
        this.gradient6 = other.gradient6
        this.gradient7 = other.gradient7
        this.gradient8 = other.gradient8
        this.gradient9 = other.gradient9
        this.gradient10 = other.gradient10
        this.gradient11 = other.gradient11
        this.gradient12 = other.gradient12
        this.gradient13 = other.gradient13
        this.gradient14 = other.gradient14
        this.gradient15 = other.gradient15
        this.additionalGreen = other.additionalGreen
        this.inverted = other.inverted
        this.hiddenPrizeAccent = other.hiddenPrizeAccent
        this.hiddenPrizeBackground = other.hiddenPrizeBackground
    }
}


fun darkColors() = FoundationColors(
    // primary - Foundation brandGreen #047857 (iOS PrimaryMain/Dark/Darker,
    // which carries the same value in its dark appearance)
    primaryDarker = Color(0xFF047857),
    primaryDark = Color(0xFF047857),
    primaryMain = Color(0xFF047857),
    primaryLight = Color(0x1F047857),
    primaryLighter = Color(0x0F047857),

    // secondary - Foundation brandCyan #22D3EE (iOS SecondaryMain);
    // replaces Rarimo's lime secondary ramp
    secondaryDarker = Color(0xFF22D3EE),
    secondaryDark = Color(0xFF22D3EE),
    secondaryMain = Color(0xFF22D3EE),
    secondaryLight = Color(0x1F22D3EE),
    secondaryLighter = Color(0x0F22D3EE),

    // success
    successDarker = Color(0xFF4AD07B),
    successDark = Color(0xFF3DD073),
    successMain = Color(0xFF37CF6F),
    successLight = Color(0x1F37CF6F),
    successLighter = Color(0x0F37CF6F),

    // info
    infoDarker = Color(0xFF5D97F5),
    infoDark = Color(0xFF4788F1),
    infoMain = Color(0xFF367BEC),
    infoLight = Color(0x1F367BEC),
    infoLighter = Color(0x0F367BEC),

    // error
    errorDarker = Color(0xFFEE6565),
    errorDark = Color(0xFFE65454),
    errorMain = Color(0xFFDA4343),
    errorLight = Color(0x1FDA4343),
    errorLighter = Color(0x0FDA4343),

    // warning
    warningBase = Color(0xFFED9E19),
    warningDarker = Color(0xFFFBB239),
    warningDark = Color(0xFFF3A728),
    warningMain = Color(0xFFED9E19),
    warningLight = Color(0x1FED9E19),
    warningLighter = Color(0x0FED9E19),

    // text
    textPrimary = Color(0xE5FFFFFF),
    textSecondary = Color(0x8FFFFFFF),
    textPlaceholder = Color(0x70FFFFFF),
    textDisabled = Color(0x47FFFFFF),

    // component
    componentPrimary = Color(0x0DFFFFFF),
    componentHovered = Color(0x1AFFFFFF),
    componentPressed = Color(0x26FFFFFF),
    componentSelected = Color(0x0DFFFFFF),
    componentDisabled = Color(0x0DFFFFFF),

    // background
    backgroundPrimary = Color(0xFF0E0E0E),
    backgroundContainer = Color(0xFF171717),
    backgroundBlur = Color(0xE50E0E0E),
    backgroundPure = Color(0xFF0E0E0E),
    backgroundSurface1 = Color(0xFF272827),
    backgroundSurface2 = Color(0xFF3F403F),

    // base
    baseBlack = Color(0xFF202020),
    baseWhite = Color(0xFFFFFFFF),

    // inverted
    invertedDark = Color(0xFFF3F6F2),
    invertedLight = Color(0xFF141614),

    // additional
    // gradient1 == iOS Gradients.gradientFirst (AdditionalGradientFirstStart /
    // End): the brand mark tint, the identity widget background and the
    // auth-method chips. brandGreen -> brandFill, the value iOS resolved to.
    gradient1 = Brush.linearGradient(colors = listOf(Color(0xFF047857), Color(0xFF34D399))),
    // gradient2/3/4 are byte-identical to iOS's AdditionalGradientSecond /
    // Third / Fourth, which Task B3 left unmapped: pale washes carrying no
    // Rarimo brand hex. Kept as-is so the two platforms stay in step; the
    // faint lime cast in gradient3 (#DFFCC4) and the lavender in gradient4
    // are flagged in the C3 report as a cross-platform follow-up, since
    // changing them here alone would create drift.
    gradient2 = Brush.linearGradient(colors = listOf(Color(0xFFF2F8EE), Color(0xFFCBE7EC))),
    gradient3 = Brush.linearGradient(colors = listOf(Color(0xFFDFFCC4), Color(0xFFF4F3F0))),
    gradient4 = Brush.linearGradient(colors = listOf(Color(0xFFD3D1EF), Color(0xFFFCE3FC))),
    // gradient5 - Freedomtool widget background. Deep forest green fading to
    // near-black: no Rarimo signature hex (their brand lime is #84CC16 /
    // #9AFE8A), so it is left as-is.
    gradient5 = Brush.linearGradient(
        colors = listOf(
            Color(0xFF255130),
            Color(0xFF0F1611)
        )
    ),
    // gradient6 is byte-identical to iOS's AdditionalGradientSixth and fills
    // the same control on both platforms (the checkbox/switch), where B3 left
    // it unmapped. Mid green/teal, not Rarimo's lime and not their purple, so
    // it stays put rather than drifting away from iOS.
    gradient6 = Brush.linearGradient(colors = listOf(Color(0xFF39CDA0), Color(0xFF45C45C))),
    // gradient7 - no consumer in the app today; Rarimo's pale lavender wash
    // swapped for a Foundation surface -> bg -> surface wash of the same
    // character, so no purple-family value survives anywhere in the palette.
    gradient7 = Brush.linearGradient(
        colors = listOf(
            Color(0xFFFFFFFF), Color(0xFFF6F9FC), Color(
                0xFFFFFFFF
            )
        )
    ),
    // gradient8 - Rarimo's purple, used BOTH as an accent-title text brush and
    // as a button fill that draws baseWhite content on top. iOS maps its
    // purple gradients to brandFill -> brandCyan, but copying that here would
    // put white text on #34D399/#22D3EE (1.9:1 / 1.8:1). A dark Foundation
    // green ramp keeps the original's dark->mid structure and stays >=5.5:1
    // against white across both stops.
    gradient8 = Brush.linearGradient(
        colors = listOf(Color(0xFF024A36), Color(0xFF047857))
    ),
    // gradient9 - no consumer today. Only the tinted first stop carried
    // Rarimo's mauve; it becomes brandGreen, whose luminance (0.139) is
    // within a hair of the mauve it replaces (0.150), so the fade into the
    // near-black stops keeps its shape in the dark theme.
    gradient9 = Brush.linearGradient(
        colors = listOf(
            Color(0xFF047857),
            Color(0xFF1C1B1D),
            Color(0xFF1C1B1D)
        )
    ),
    // gradient10 - TipAlert background. Rarimo's purple-cast near-blacks
    // become neutral Foundation dark surfaces at the same lightness.
    gradient10 = Brush.linearGradient(
        colors = listOf(
            Color(0xFF141614),
            Color(0xFF171717),
        )
    ),

    // gradient11 - recovery-method accent title. iOS paints the same screen's
    // accent with Gradients.greenText (brandGreen -> brandFill).
    gradient11 = Brush.linearGradient(
        colors = listOf(
            Color(0xFF047857),
            Color(0xFF34D399),
        )
    ),
    // gradient12 - the "SOON" badge capsule, which draws baseBlack text on
    // top, so the fill has to stay pale. Same role and same pastel-mint values
    // as iOS's Gradients.lightGreenBg (LightGreenBgGradient1/2).
    gradient12 = Brush.linearGradient(
        colors = listOf(
            Color(0xFFC2F2E0),
            Color(0xFF8FE7C7),
        )
    ),
    // gradient13 - Earn/RMO accent title, the role iOS paints with
    // Gradients.darkerGreenText. iOS's DarkerGreenTextGradient1/2 resolve to
    // #34D399 in the DARK appearance (and #024A36 in the light one), so the
    // dark theme keeps a bright stop rather than inheriting the light value.
    gradient13 = Brush.linearGradient(
        colors = listOf(
            Color(0xFF34D399),
            Color(0xFF34D399)
        )
    ),
    // gradient14 - Likeness accent title. Rarimo's olive/lime pair replaced by
    // iOS's Gradients.greenText values (brandGreen -> brandFill), which carry
    // the same hex in both iOS appearances.
    gradient14 = Brush.linearGradient(
        colors = listOf(
            Color(0xFF047857),
            Color(0xFF34D399)
        )
    ),
    // gradient15 - Freedomtool/voting accent title, the same role iOS paints
    // with Gradients.darkGreenText (DarkGreenTextGradient1/2 = brandGreen on
    // both stops, which is also how near-flat Rarimo's original pair was).
    gradient15 = Brush.linearGradient(
        colors = listOf(
            Color(0xFF047857),
            Color(0xFF047857)
        )
    ),

    // additionalGreen - iOS AdditionalGreen, dark appearance (#1C211D). No
    // consumer on Android today; kept at parity with iOS rather than left on
    // Rarimo's near-white value.
    additionalGreen = Color(0xFF1C211D),


    baseBlackOp40 = Color(0x66141614),
    baseBlackOp50 = Color(0x80141614),
    inverted = Color(0xFF000000),
    // hiddenPrize* - Rarimo purple replaced by the Foundation brand family;
    // the accent is drawn as icon/title colour over a 10% tint of itself, so
    // the dark theme takes brandFill and the light theme brandGreen.
    hiddenPrizeAccent = Color(0xFF34D399),
    hiddenPrizeBackground = Color(0xFF1C211D),
    welcomeAccent1 = Color(0xFF1B1B1A),
    welcomeAccent2 = Color(0xFF1E2020),
    welcomeAccent3 = Color(0xFF1F221F),
    welcomeAccent4 = Color(0xFF201F21)
)

fun lightColors() = FoundationColors(
    // primary - Foundation brandGreen #047857 (iOS PrimaryMain/Dark/Darker).
    // primaryLight/Lighter were written as 0x1416141F / 0x1416140F upstream,
    // i.e. RGBA instead of ARGB, so they rendered an 8%-alpha #16141F rather
    // than a 12%/6% tint of the primary; they now carry the intended alphas.
    primaryDarker = Color(0xFF047857),
    primaryDark = Color(0xFF047857),
    primaryMain = Color(0xFF047857),
    primaryLight = Color(0x1F047857),
    primaryLighter = Color(0x0F047857),

    // secondary - Foundation brandCyan #22D3EE (iOS SecondaryMain);
    // replaces Rarimo's lime secondary ramp
    secondaryDarker = Color(0xFF22D3EE),
    secondaryDark = Color(0xFF22D3EE),
    secondaryMain = Color(0xFF22D3EE),
    secondaryLight = Color(0x1F22D3EE),
    secondaryLighter = Color(0x0F22D3EE),

    // success
    successDarker = Color(0xFF15803D),
    successDark = Color(0xFF16A34A),
    successMain = Color(0xFF22C55E),
    successLight = Color(0x1F22C55E),
    successLighter = Color(0x0F22C55E),

    // info
    infoDarker = Color(0xFF1D4ED8),
    infoDark = Color(0xFF2563EB),
    infoMain = Color(0xFF3B82F6),
    infoLight = Color(0x1F3B82F6),
    infoLighter = Color(0x0F3B82F6),

    // error
    errorDarker = Color(0xFFB91C1C),
    errorDark = Color(0xFFDC2626),
    errorMain = Color(0xFFEF4444),
    errorLight = Color(0x1FEF4444),
    errorLighter = Color(0x0FEF4444),

    // warning
    warningBase = Color(0xFFED9E19),
    warningDarker = Color(0xFFC09027),
    warningDark = Color(0xFFE1AC3B),
    warningMain = Color(0xFFF59E0B),
    warningLight = Color(0x1FF59E0B),
    warningLighter = Color(0x0FF59E0B),

    // text - Foundation `text` #0A0E27 and `muted` #596171, keeping each
    // tier's own alpha (iOS TextPrimary / TextSecondary 0.56 / TextPlaceholder
    // 0.44 / TextDisabled 0.28)
    textPrimary = Color(0xFF0A0E27),
    textSecondary = Color(0x8F596171),
    textPlaceholder = Color(0x70596171),
    textDisabled = Color(0x47596171),

    // component
    componentPrimary = Color(0x0D141614),
    componentHovered = Color(0x1A141614),
    componentPressed = Color(0x26141614),
    componentSelected = Color(0x0D141614),
    componentDisabled = Color(0x0D141614),

    // background - Foundation `bg` #F6F9FC for the page ground (iOS BgPrimary,
    // BgPure), `surface` #FFFFFF for raised surfaces (iOS BgContainer,
    // BgSurface1/2, BgBlur at 90%)
    backgroundPrimary = Color(0xFFF6F9FC),
    backgroundContainer = Color(0xFFFFFFFF),
    backgroundBlur = Color(0xE5FFFFFF),
    backgroundPure = Color(0xFFF6F9FC),
    backgroundSurface1 = Color(0xFFFFFFFF),
    backgroundSurface2 = Color(0xFFFFFFFF),

    // base
    baseBlack = Color(0xFF141614),
    baseWhite = Color(0xFFFFFFFF),


    // inverted
    invertedDark = Color(0xFF141614),
    invertedLight = Color(0xFFFFFFFF),

    // additional
    // gradient1 == iOS Gradients.gradientFirst (AdditionalGradientFirstStart /
    // End): the brand mark tint, the identity widget background and the
    // auth-method chips. brandGreen -> brandFill, the value iOS resolved to.
    gradient1 = Brush.linearGradient(colors = listOf(Color(0xFF047857), Color(0xFF34D399))),
    // gradient2/3/4 are byte-identical to iOS's AdditionalGradientSecond /
    // Third / Fourth, which Task B3 left unmapped: pale washes carrying no
    // Rarimo brand hex. Kept as-is so the two platforms stay in step; the
    // faint lime cast in gradient3 (#DFFCC4) and the lavender in gradient4
    // are flagged in the C3 report as a cross-platform follow-up, since
    // changing them here alone would create drift.
    gradient2 = Brush.linearGradient(colors = listOf(Color(0xFFF2F8EE), Color(0xFFCBE7EC))),
    gradient3 = Brush.linearGradient(colors = listOf(Color(0xFFDFFCC4), Color(0xFFF4F3F0))),
    gradient4 = Brush.linearGradient(colors = listOf(Color(0xFFD3D1EF), Color(0xFFFCE3FC))),
    // gradient5 - Freedomtool widget background. Soft mint fading to
    // near-white; sits in the brandFill family rather than Rarimo's neon
    // lime, so it is left as-is.
    gradient5 = Brush.linearGradient(
        colors = listOf(
            Color(0xFFA2F0B6),
            Color(0xFFF2F9F0)
        )
    ),
    // gradient6 is byte-identical to iOS's AdditionalGradientSixth and fills
    // the same control on both platforms (the checkbox/switch), where B3 left
    // it unmapped. Mid green/teal, not Rarimo's lime and not their purple, so
    // it stays put rather than drifting away from iOS.
    gradient6 = Brush.linearGradient(colors = listOf(Color(0xFF39CDA0), Color(0xFF45C45C))),
    // gradient7 - no consumer in the app today; Rarimo's pale lavender wash
    // swapped for a Foundation surface -> bg -> surface wash of the same
    // character, so no purple-family value survives anywhere in the palette.
    gradient7 = Brush.linearGradient(
        colors = listOf(
            Color(0xFFFFFFFF), Color(0xFFF6F9FC), Color(
                0xFFFFFFFF
            )
        )
    ),

    // gradient8 - see the dark-theme block: dark Foundation green ramp,
    // white-content-safe, replacing Rarimo's purple.
    gradient8 = Brush.linearGradient(colors = listOf(Color(0xFF024A36), Color(0xFF047857))),
    // gradient9 - no consumer today. Rarimo's pale lavender first stop becomes
    // the pastel mint iOS already uses for its light green background
    // (LightGreenBgGradient1), at a matching lightness.
    gradient9 = Brush.linearGradient(
        colors = listOf(
            Color(0xFFC2F2E0),
            Color(0xFFF1F0F2),
            Color(0xFFF1F0F2)
        )
    ),
    // gradient10 - TipAlert background. Rarimo's purple-cast near-whites
    // become Foundation `bg` -> `surface`.
    gradient10 = Brush.linearGradient(
        colors = listOf(
            Color(0xFFF6F9FC),
            Color(0xFFFFFFFF),
        )
    ),
    // gradient11 - recovery-method accent title. iOS paints the same screen's
    // accent with Gradients.greenText (brandGreen -> brandFill).
    gradient11 = Brush.linearGradient(
        colors = listOf(
            Color(0xFF047857),
            Color(0xFF34D399),
        )
    ),
    // gradient12 - the "SOON" badge capsule, which draws baseBlack text on
    // top, so the fill has to stay pale. Same role and same pastel-mint values
    // as iOS's Gradients.lightGreenBg (LightGreenBgGradient1/2).
    gradient12 = Brush.linearGradient(
        colors = listOf(
            Color(0xFFC2F2E0),
            Color(0xFF8FE7C7),
        )
    ),

    // gradient13 - Earn/RMO accent title; iOS DarkerGreenTextGradient1/2,
    // light appearance (#024A36).
    gradient13 = Brush.linearGradient(
        colors = listOf(
            Color(0xFF024A36),
            Color(0xFF024A36)
        )
    ),

    // gradient14 - Likeness accent title; see the dark-theme block.
    gradient14 = Brush.linearGradient(
        colors = listOf(
            Color(0xFF047857),
            Color(0xFF34D399)
        )
    ),

    // gradient15 - Freedomtool/voting accent title, the same role iOS paints
    // with Gradients.darkGreenText (DarkGreenTextGradient1/2 = brandGreen on
    // both stops, which is also how near-flat Rarimo's original pair was).
    gradient15 = Brush.linearGradient(
        colors = listOf(
            Color(0xFF047857),
            Color(0xFF047857)
        )
    ),

    baseBlackOp40 = Color(0x66141614),
    baseBlackOp50 = Color(0x80141614),

    // additionalGreen - iOS AdditionalGreen, light appearance (Foundation
    // `bg` #F6F9FC). No consumer on Android today.
    additionalGreen = Color(0xFFF6F9FC),
    inverted = Color(0xFFFFFFFF),

    // hiddenPrize* - Rarimo purple replaced by the Foundation brand family;
    // see the dark-theme block.
    hiddenPrizeAccent = Color(0xFF047857),
    hiddenPrizeBackground = Color(0xFFF6F9FC),

    welcomeAccent1 = Color(0xFFF9F9F2),
    welcomeAccent2 = Color(0xFFE2EBED),
    welcomeAccent3 = Color(0xFFEEF4EE),
    welcomeAccent4 = Color(0xFFF7F4F9)

)

val LocalColors = staticCompositionLocalOf { lightColors() }