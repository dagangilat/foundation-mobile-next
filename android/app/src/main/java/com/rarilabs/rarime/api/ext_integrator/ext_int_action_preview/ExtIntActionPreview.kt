package com.rarilabs.rarime.api.ext_integrator.ext_int_action_preview

import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.rarilabs.rarime.api.ext_integrator.ext_int_action_preview.handlers.ext_int_query_proof_handler.ExtIntQueryProofHandler
import com.rarilabs.rarime.api.ext_integrator.models.ExtIntegratorActions
import com.rarilabs.rarime.ui.theme.FoundationTheme

@Composable
fun ExtIntActionPreview(
    dataUri: Uri?,
    navigate: (String) -> Unit,
    onCancel: () -> Unit = {},
    onSuccess: (extDestination: String?, localDestination: String?) -> Unit = { extDestination, localDestination -> },
    onError: () -> Unit = {}
) {
    val queryParams = remember {
        dataUri?.queryParameterNames?.associateWith { paramName ->
            dataUri.getQueryParameter(paramName)
        }
    }
    val requestType = remember {
        queryParams?.get("type")
    }

    if (queryParams?.isNotEmpty() == true) {
        when (requestType) {
            ExtIntegratorActions.QueryProofGen.value -> {
                ExtIntQueryProofHandler(
                    queryParams = queryParams,
                    onCancel = onCancel,
                    onSuccess = { destination -> onSuccess(destination, null) },
                    onFail = { onError() }
                )
            }

            // The `light-verification` and `vote` actions were handled here by
            // LightProofHandler / VoteHandler. Foundation verifies with the full
            // query proof and does not run Freedom Tool voting, so both handlers
            // are removed and those deep links now fall through to the
            // not-implemented branch below.

            else -> {
                Column(
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.Center,
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = "Not implemented",
                        style = FoundationTheme.typography.subtitle4,
                        color = FoundationTheme.colors.textPrimary
                    )
                }
            }
        }
    }
}
