package com.rarilabs.rarime.modules.home.v3

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.ExperimentalSharedTransitionApi
import androidx.compose.animation.SharedTransitionScope
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.pager.VerticalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.util.lerp
import androidx.compose.ui.zIndex
import androidx.hilt.navigation.compose.hiltViewModel
import com.rarilabs.rarime.R
import com.rarilabs.rarime.data.enums.AppColorScheme
import com.rarilabs.rarime.foundation.ui.BrandLockup
import com.rarilabs.rarime.foundation.ui.FoundationIconButton
import com.rarilabs.rarime.foundation.ui.FoundationVerifyCard
import com.rarilabs.rarime.foundation.ui.PillarsHero
import com.rarilabs.rarime.modules.home.v3.model.ANIMATION_DURATION_MS
import com.rarilabs.rarime.modules.home.v3.model.BaseWidgetProps
import com.rarilabs.rarime.modules.home.v3.model.WidgetType
import com.rarilabs.rarime.modules.home.v3.ui.collapsed.RecoveryMethodCollapsedWidget
import com.rarilabs.rarime.modules.home.v3.ui.components.HomeHeader
import com.rarilabs.rarime.modules.home.v3.ui.components.VerticalPageIndicator
import com.rarilabs.rarime.modules.home.v3.ui.expanded.RecoveryMethodExpandedWidget
import com.rarilabs.rarime.modules.main.LocalMainViewModel
import com.rarilabs.rarime.modules.main.ScreenInsets
import com.rarilabs.rarime.modules.manageWidgets.ManageWidgetsButton
import com.rarilabs.rarime.ui.theme.FoundationBrand
import com.rarilabs.rarime.ui.theme.FoundationTheme
import com.rarilabs.rarime.util.PrevireSharedAnimationProvider
import com.rarilabs.rarime.util.Screen
import kotlinx.coroutines.delay
import kotlin.math.abs

/**
 * Foundation Home: the lockup with a profile button, the pillars in the mesh
 * hero, then the status card (verify / verified, which starts the passport
 * flow) and "Scan QR code" under it.
 *
 * The fork's widget pager ([HomeScreenContent]), its "Hi Stranger" header and
 * notifications bell, the manage-widgets sheet and the welcome sheet are no
 * longer composed here. Their code is kept, just unhooked.
 */
@OptIn(ExperimentalSharedTransitionApi::class)
@Composable
fun HomeScreenV3(
    navigate: (String) -> Unit,
    navigateWithPopUp: (String) -> Unit,
    @Suppress("UNUSED_PARAMETER") sharedTransitionScope: SharedTransitionScope,
    setVisibilityOfBottomBar: (Boolean) -> Unit,
    @Suppress("UNUSED_PARAMETER") viewModel: HomeViewModel = hiltViewModel(),
) {
    val innerPaddings by LocalMainViewModel.current.screenInsets.collectAsState()

    // There is no tab bar in the Foundation shell.
    LaunchedEffect(Unit) {
        setVisibilityOfBottomBar(false)
    }

    FoundationHomeContent(
        innerPaddings = innerPaddings,
        onProfileClick = { navigate(Screen.Main.Profile.route) },
        // A slot rather than composed inside FoundationHomeContent so the
        // preview stays renderable - FoundationVerifyCard resolves a
        // @HiltViewModel, which no @Preview can provide.
        statusCard = {
            FoundationVerifyCard(
                // The Identity route is the same screen the old Identity tab
                // opened: the passport scan while no passport is stored, then
                // the registration that produces the proof this card waits
                // for. It closes back to Home.
                onScanPassport = { navigate(Screen.Main.Identity.route) },
                // Shows the QR scan sheet mounted in MainScreen (the flow the
                // old QR tab opened); a scanned partner request runs through
                // ExtIntActionPreview like any deep link.
                onScanQr = { navigateWithPopUp(Screen.Main.QrScan.route) },
            )
        },
    )
}

@Composable
fun FoundationHomeContent(
    innerPaddings: Map<ScreenInsets, Number>,
    onProfileClick: () -> Unit,
    modifier: Modifier = Modifier,
    statusCard: @Composable () -> Unit = {},
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(FoundationBrand.Bg)
            .padding(
                top = innerPaddings[ScreenInsets.TOP]?.toFloat()?.dp ?: 0.dp,
                bottom = innerPaddings[ScreenInsets.BOTTOM]?.toFloat()?.dp ?: 0.dp
            )
            .verticalScroll(rememberScrollState())
            .padding(start = 24.dp, end = 24.dp, top = 12.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(44.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            BrandLockup()
            Spacer(modifier = Modifier.weight(1f))
            FoundationIconButton(
                icon = R.drawable.ic_fnd_user_circle,
                contentDescription = "Profile",
                onClick = onProfileClick,
            )
        }

        PillarsHero()

        statusCard()
    }
}

/**
 * The fork's widget-pager Home. No longer composed by [HomeScreenV3]; kept
 * (with its preview) so the widget code stays buildable.
 */
@OptIn(ExperimentalSharedTransitionApi::class)
@Composable
fun HomeScreenContent(
    modifier: Modifier = Modifier,
    innerPaddings: Map<ScreenInsets, Number>,
    navigate: (String) -> Unit,
    sharedTransitionScope: SharedTransitionScope,
    setVisibilityOfBottomBar: (Boolean) -> Unit,
    visibleWidgets: List<WidgetType>,
    userPassportName: String?,
    notificationsCount: Int?,
    colorScheme: AppColorScheme,
    onClick: () -> Unit,
    verifyCard: @Composable () -> Unit = {}
) {
    var selectedWidgetType by remember { mutableStateOf<WidgetType?>(null) }
    LaunchedEffect(selectedWidgetType) {
        setVisibilityOfBottomBar(selectedWidgetType == null)
    }

    val pagerState = rememberPagerState(pageCount = { visibleWidgets.size })

    Box(modifier = modifier) {
        var pagerScrollEnabled by remember { mutableStateOf(true) }
        LaunchedEffect(selectedWidgetType) {
            pagerScrollEnabled = false
            delay((ANIMATION_DURATION_MS + 200).toLong())
            pagerScrollEnabled = true
        }

        AnimatedContent(selectedWidgetType) { targetCardType ->
            if (targetCardType == null) {
                Column(
                    modifier = Modifier.padding(
                        top = innerPaddings[ScreenInsets.TOP]?.toFloat()?.dp ?: 0.dp,
                        bottom = innerPaddings[ScreenInsets.BOTTOM]?.toFloat()?.dp ?: 0.dp
                    )
                ) {
                    HomeHeader(
                        notificationsCount = notificationsCount,
                        name = userPassportName,
                        onNotificationClick = { navigate(Screen.NotificationsList.route) })

                    // Foundation verification entry point, above the widget list.
                    verifyCard()

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        VerticalPager(
                            modifier = Modifier.weight(1f),
                            userScrollEnabled = pagerScrollEnabled,
                            state = pagerState,
                            pageSpacing = 5.dp,
                            contentPadding = PaddingValues(top = 0.dp, bottom = 70.dp),
                            key = { page -> visibleWidgets[page].layoutId }

                        ) { page ->

                            val widgetType = visibleWidgets[page]
                            val currentPage = pagerState.currentPage
                            val currentOffset = pagerState.currentPageOffsetFraction
                            val pageOffset = (currentPage - page) + currentOffset
                            val absoluteOffset = abs(pageOffset).coerceIn(0f, 1f)
                            val targetScale = lerp(0.9f, 1f, 1f - absoluteOffset)
                            val scale by animateFloatAsState(
                                targetValue = targetScale, animationSpec = spring(
                                    dampingRatio = 0.5f, stiffness = 300f
                                )
                            )

                            val onExpand = remember(pagerScrollEnabled, widgetType) {
                                {
                                    if (pagerScrollEnabled) {
                                        selectedWidgetType = widgetType
                                    }
                                }
                            }

                            val collapsedWidgetProps = BaseWidgetProps.Collapsed(
                                onExpand = onExpand,
                                layoutId = widgetType.layoutId,
                                animatedVisibilityScope = this@AnimatedContent,
                                sharedTransitionScope = sharedTransitionScope
                            )

                            val baseCollapsedModifier = Modifier.graphicsLayer {
                                scaleX = scale
                                scaleY = scale
                                alpha = lerp(0.8f, 1f, 1f - absoluteOffset)
                            }
                            when (widgetType) {
                                WidgetType.RECOVERY_METHOD -> RecoveryMethodCollapsedWidget(
                                    collapsedWidgetProps = collapsedWidgetProps,
                                    modifier = baseCollapsedModifier,
                                    colorScheme = colorScheme
                                )

                                // TODO: Implement rest collapsed cards here
                            }


                        }
                        VerticalPageIndicator(
                            totalPages = pagerState.pageCount,
                            selectedPage = pagerState.currentPage,
                            modifier = Modifier.padding(end = 8.dp),
                            defaultSize = 6.dp,
                            selectedColor = FoundationTheme.colors.primaryMain,
                            defaultColor = FoundationTheme.colors.primaryLight,
                            selectedHeight = 16.dp,
                            space = 8.dp
                        )

                    }

                }

                if (pagerState.currentPage == pagerState.pageCount - 1) {
                    ManageWidgetsButton(innerPaddings = innerPaddings, onClick = onClick)
                }

            } else {
                // Expanded: one card is visible on top
                BackHandler {
                    selectedWidgetType = null
                }

                Box(
                    modifier = Modifier.align(Alignment.TopCenter)
                ) {
                    // Common props for every expanded card
                    val expandedCardProps = BaseWidgetProps.Expanded(
                        onCollapse = { selectedWidgetType = null },
                        layoutId = targetCardType.layoutId,
                        animatedVisibilityScope = this@AnimatedContent,
                        sharedTransitionScope = sharedTransitionScope
                    )

                    when (targetCardType) {
                        WidgetType.RECOVERY_METHOD -> RecoveryMethodExpandedWidget(
                            expandedWidgetProps = expandedCardProps,
                            innerPaddings = innerPaddings,
                            navigate = navigate
                        )

                        // TODO: Implement rest expanded cards here
                    }
                }
            }
        }


        if (!pagerScrollEnabled) {
            Box(
                modifier = Modifier
                    .background(Color.Transparent)
                    .zIndex(200f)
                    .matchParentSize()
                    .pointerInput(Unit) {
                        awaitPointerEventScope {
                            while (true) {
                                awaitPointerEvent()
                            }
                        }
                    })
        }
    }
}

@OptIn(ExperimentalSharedTransitionApi::class)
@Preview
@Composable
private fun HomeScreenPreview() {
    PrevireSharedAnimationProvider { sharedTransitionScope, _ ->
        Surface {
            HomeScreenContent(
                modifier = Modifier.fillMaxSize(),
                sharedTransitionScope = sharedTransitionScope,
                navigate = {},
                setVisibilityOfBottomBar = {},
                userPassportName = "Mike",
                notificationsCount = 2,
                innerPaddings = mapOf(ScreenInsets.TOP to 0, ScreenInsets.BOTTOM to 0),
                visibleWidgets = WidgetType.entries,
                colorScheme = AppColorScheme.SYSTEM,
                onClick = {})
        }
    }
}

@Preview
@Composable
private fun FoundationHomePreview() {
    FoundationHomeContent(
        innerPaddings = mapOf(ScreenInsets.TOP to 0, ScreenInsets.BOTTOM to 0),
        onProfileClick = {},
    )
}
