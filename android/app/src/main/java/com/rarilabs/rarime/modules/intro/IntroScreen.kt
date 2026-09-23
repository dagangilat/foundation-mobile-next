package com.rarilabs.rarime.modules.intro

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.rarilabs.rarime.foundation.ui.BrandLockup
import com.rarilabs.rarime.foundation.ui.FoundationButton
import com.rarilabs.rarime.foundation.ui.FoundationButtonStyle
import com.rarilabs.rarime.foundation.ui.PillarsHero
import com.rarilabs.rarime.ui.theme.FoundationBrand
import com.rarilabs.rarime.ui.theme.FoundationType
import com.rarilabs.rarime.util.Screen

@Composable
fun IntroScreen(
    onFinish: (String) -> Unit,
    onNavigate: (String) -> Unit,
    viewModel: IntroViewModel = hiltViewModel()
) {

    IntroScreenContent(
        onFinish = onFinish,
        genPrivateKey = viewModel::savePrivateKey,
        navigate = onNavigate
    )
}

/**
 * First run after sign-in: create the on-device key, or restore one.
 *
 * The Foundation "Your private ID" screen (approved mockup "Welcome"): the
 * lockup, a smaller pillars hero, one plain sentence on what the key is, then
 * "Create my ID" (the existing new-identity path) and "Restore from backup"
 * (the existing import-identity route). Replaces the fork's black logo tile
 * and animated carousel; the two actions are exactly the ones it offered.
 */
@Composable
fun IntroScreenContent(
    navigate: (String) -> Unit,
    genPrivateKey: () -> Unit,
    onFinish: (String) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(FoundationBrand.Bg)
            .verticalScroll(rememberScrollState())
            .padding(start = 24.dp, end = 24.dp, top = 20.dp, bottom = 20.dp),
    ) {
        Row(modifier = Modifier.height(44.dp), verticalAlignment = Alignment.CenterVertically) {
            BrandLockup()
        }
        Spacer(modifier = Modifier.height(32.dp))
        PillarsHero(textSize = 38.sp, iconSize = 32.dp, rowSpacing = 3.dp)
        Spacer(modifier = Modifier.height(36.dp))
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(text = "Your private ID", style = FoundationType.title, color = FoundationBrand.Text)
            Text(
                text = "Foundation creates a private key that lives only on this phone. " +
                    "It lets you prove you're a real person without showing who you are.",
                style = FoundationType.body,
                color = FoundationBrand.Muted,
            )
        }
        Spacer(modifier = Modifier.height(40.dp))
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            FoundationButton(
                text = "Create my ID",
                onClick = {
                    genPrivateKey()
                    onFinish(Screen.Main.Home.route)
                },
            )
            FoundationButton(
                text = "Restore from backup",
                style = FoundationButtonStyle.Text,
                onClick = { navigate(Screen.Register.ImportIdentity.route) },
            )
        }
    }
}

@Preview
@Composable
private fun IntroScreenPreview() {
    IntroScreenContent(navigate = {}, genPrivateKey = {}, onFinish = {})
}
