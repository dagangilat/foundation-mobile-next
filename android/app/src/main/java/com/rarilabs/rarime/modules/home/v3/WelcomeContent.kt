package com.rarilabs.rarime.modules.home.v3

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.rarilabs.rarime.R
import com.rarilabs.rarime.ui.base.ButtonSize
import com.rarilabs.rarime.ui.components.AppBottomSheet
import com.rarilabs.rarime.ui.components.AppIcon
import com.rarilabs.rarime.ui.components.CircledBadge
import com.rarilabs.rarime.ui.components.HorizontalDivider
import com.rarilabs.rarime.ui.components.HorizontalPageIndicator
import com.rarilabs.rarime.ui.components.PrimaryButton
import com.rarilabs.rarime.ui.components.rememberAppSheetState
import com.rarilabs.rarime.ui.theme.FoundationTheme
import kotlinx.coroutines.launch

/**
 * One page of the first-run welcome pager.
 *
 * [iconId] is a plain glyph rather than an illustration: no Foundation-specific
 * onboarding artwork exists yet, so — mirroring the iOS client's
 * `HomeOnboardingView` (Open Decision OD-6) — each step shows an icon from the
 * app's own icon set instead of shipping the upstream fork's branded art.
 */
data class WelcomeCardContent(
    val title: String,
    val iconId: Int,
    val description: String,
    val accentColor: Color
)


@Composable
fun WelcomeBottomSheet(
    onClose: () -> Unit,
) {

    val welcomeAccentColor1 = FoundationTheme.colors.welcomeAccent1
    val welcomeAccentColor2 = FoundationTheme.colors.welcomeAccent2
    val welcomeAccentColor3 = FoundationTheme.colors.welcomeAccent3
    val welcomeAccentColor4 = FoundationTheme.colors.welcomeAccent4

    val context = LocalContext.current

    val scope = rememberCoroutineScope()

    val cardContent = remember {
        listOf(
            WelcomeCardContent(
                title = context.getString(R.string.welcome_card1_title),
                // iOS uses `.globeSimple` here; this fork's icon set has no plain
                // globe (only the "x" and "time" variants, which read as
                // blocked/pending), so follow the card's own copy instead.
                iconId = R.drawable.ic_cardholder,
                description = context.getString(R.string.welcome_card1_description),
                accentColor = welcomeAccentColor1

            ), WelcomeCardContent(
                title = context.getString(R.string.welcome_card2_title),
                iconId = R.drawable.ic_shield_keyhole_line,
                description = context.getString(R.string.welcome_card2_description),
                accentColor = welcomeAccentColor2


            ), WelcomeCardContent(
                title = context.getString(R.string.welcome_card3_title),
                iconId = R.drawable.ic_identification_card,
                description = context.getString(R.string.welcome_card3_description),
                accentColor = welcomeAccentColor3


            ), WelcomeCardContent(
                title = context.getString(R.string.welcome_card4_title),
                iconId = R.drawable.ic_box_3_line,
                description = context.getString(R.string.welcome_card4_description),
                accentColor = welcomeAccentColor4

            )
        )
    }

    val pagerState = rememberPagerState { cardContent.size }


    Box {
        val animatedColor by animateColorAsState(
            targetValue = cardContent[pagerState.currentPage].accentColor,
            animationSpec = tween(durationMillis = 500)
        )
        Column(modifier = Modifier.matchParentSize()) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(225.dp)
                    .background(animatedColor)
            ) {}
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .fillMaxSize()
                    .background(FoundationTheme.colors.backgroundSurface1)
            ) {}
        }

        Column {
            HorizontalPager(
                state = pagerState
            ) {
                BaseWelcomeContent(
                    modifier = Modifier.padding(start = 24.dp, top = 24.dp, end = 24.dp),
                    iconId = cardContent[it].iconId,
                    title = cardContent[it].title,
                    description = cardContent[it].description
                )
            }

            Spacer(Modifier.height(32.dp))


            HorizontalDivider()

            Spacer(Modifier.height(32.dp))



            WelcomeBottomBar(
                modifier = Modifier.padding(
                    end = 24.dp,
                    start = 24.dp,
                    bottom = 20.dp
                ),
                selectedPage = pagerState.currentPage,
                numberOfPages = pagerState.pageCount,
                onNext = {
                    scope.launch {
                        pagerState.animateScrollToPage(
                            pagerState.currentPage + 1, animationSpec = tween(
                                durationMillis = 500,
                            )
                        )
                    }
                },
                onExplore = onClose
            )
        }
    }

}


@Composable
fun BaseWelcomeContent(
    modifier: Modifier = Modifier, iconId: Int, title: String, description: String
) {

    Column(modifier) {
        Row(modifier = Modifier.fillMaxWidth()) {
            CircledBadge(
                iconId = R.drawable.ic_foundation_mark,
                containerColor = FoundationTheme.colors.componentPrimary,
                // Overrides the default: this badge sits on a translucent
                // neutral, not on primaryMain.
                contentColor = FoundationTheme.colors.baseBlack,
                contentSize = 24,
                containerSize = 40
            )
            Spacer(Modifier.weight(1f))
            Column(
                // Height is fixed so every page reserves the same art slot and
                // the pager does not resize between steps.
                modifier = Modifier.height(268.dp),
                horizontalAlignment = Alignment.End,
                verticalArrangement = Arrangement.Center
            ) {
                AppIcon(
                    id = iconId,
                    size = 148.dp,
                    tint = FoundationTheme.colors.textPrimary
                )
            }

            Spacer(Modifier.weight(0.5f))
        }

        Column(modifier = Modifier.padding(top = 32.dp)) {
            Text(title, style = FoundationTheme.typography.h2, color = FoundationTheme.colors.textPrimary)
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                description,
                style = FoundationTheme.typography.body3,
                color = FoundationTheme.colors.textSecondary
            )


        }
    }
}


@Composable
fun WelcomeBottomBar(
    modifier: Modifier = Modifier,
    selectedPage: Int,
    numberOfPages: Int,
    onNext: () -> Unit,
    onExplore: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .then(modifier),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (numberOfPages - 1 == selectedPage) {
            PrimaryButton(
                modifier = Modifier.fillMaxWidth(),
                text = "Explore Apps",
                onClick = onExplore,
                size = ButtonSize.Large
            )
        } else {

            HorizontalPageIndicator(
                defaultRadius = 6.dp,
                selectedLength = 16.dp,
                space = 8.dp,
                selectedColor = FoundationTheme.colors.primaryMain,
                defaultColor = FoundationTheme.colors.primaryLight,
                selectedPage = selectedPage,
                numberOfPages = numberOfPages
            )

            PrimaryButton(
                size = ButtonSize.Large,
                onClick = onNext,
                text = "Next",
                rightIcon = R.drawable.ic_arrow_right
            )

        }
    }
}


@Preview
@Composable
private fun WelcomeBottomSheetPreview() {
    WelcomeBottomSheet {}
}

@Preview(showSystemUi = true)
@Composable
private fun WelcomeBottomBarPreview() {


    val appBottomSheet = rememberAppSheetState(false)

    Surface {
        PrimaryButton(onClick = { appBottomSheet.show() })
        AppBottomSheet(state = appBottomSheet) {
            WelcomeBottomSheet {}
        }

    }

}