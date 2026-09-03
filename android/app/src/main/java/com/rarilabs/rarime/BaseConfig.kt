package com.rarilabs.rarime

import com.rarilabs.rarime.config.Keys
import com.rarilabs.rarime.data.RarimoChains

val BaseConfig: IConfig = if (BuildConfig.isTestnet) TestNetConfig else MainnetConfig

interface IConfig {
    val APPSFLYER_DEV_KEY: String
    val RELAYER_URL: String
    val EVM_RPC_URL: String
    val COSMOS_RPC_URL: String
    val EVM_SERVICE_URL: String
    val DISCORD_URL: String
    val TWITTER_URL: String
    val INVITATION_BASE_URL: String
    val POINTS_SVC_ID: String
    val AIRDROP_SVC_ID: String
    val ICAO_COSMOS_RPC: String
    val MASTER_CERTIFICATES_FILENAME: String
    val MASTER_CERTIFICATES_BUCKETNAME: String
    val EVM_STABLE_COIN_RPC: String
    val STABLE_COIN_ADDRESS: String
    val REGISTER_CONTRACT_ADDRESS: String
    val CERTIFICATES_SMT_CONTRACT_ADDRESS: String
    val REGISTRATION_SMT_CONTRACT_ADDRESS: String
    val STATE_KEEPER_CONTRACT_ADDRESS: String
    val REGISTRATION_SIMPLE_CONTRACT_ADRRESS: String
    val POINTS_SVC_SELECTOR: String
    val POINTS_SVC_ALLOWED_IDENTITY_TIMESTAMP: Long
    val FEEDBACK_EMAIL: String
    val CHAIN: RarimoChains
    val lightVerificationSKHex: String
    val GLOBAL_NOTIFICATION_TOPIC: String
    val REWARD_NOTIFICATION_TOPIC: String
    val GOOGLE_WEB_KEY: String
    val APP_ID_FIREBASE: String
    val EXPLORER_API_URL: String
    val VOTING_RELAYER_URL: String
    val RARIMO_EXPLORER: String
    val VOTING_REGISTRATION_SMT_CONTRACT_ADDRESS: String

    val VOTING_RPC_URL: String

    val PROPOSAL_CONTRACT_ADDRESS: String

    val MULTICALL_CONTRACT_ADDRRESS: String

    val VOTING_WEBSITE_URL: String

    val FACE_REGISTRY_ADDRESS: String

    val FACE_REGISTRY_ZKEY_URL: String


    val FACE_RECOGNITION_MODEL_URL: String

    val GUESS_CELEBRITY_CONTRACT_ADDRESS: String

    val NOIR_TRUSTED_SETUP_URL: String


    val registerIdentity_1_256_3_5_576_248_NA: String
    val registerIdentity_2_256_3_6_336_264_21_2448_6_2008: String


    val registerIdentity_1_256_3_6_576_264_1_2448_3_256: String
    val registerIdentity_2_256_3_6_336_248_1_2432_3_256: String
    val registerIdentity_2_256_3_6_576_248_1_2432_3_256: String

    val registerIdentity_1_256_3_4_600_248_1_1496_3_256: String

    val registerIdentity_1_160_3_4_576_200_NA: String


    val registerIdentity_20_256_3_3_336_224_NA: String


    val registerIdentity_10_256_3_3_576_248_1_1184_5_264: String
    val registerIdentity_21_256_3_3_576_232_NA: String


    val registerIdentity_21_256_3_4_576_232_NA: String


    val registerIdentity_14_256_3_4_336_64_1_1480_5_296: String

    val registerIdentity_1_256_3_6_336_560_1_2744_4_256: String
    val registerIdentity_20_256_3_5_336_72_NA: String

    val registerIdentity_4_160_3_3_336_216_1_1296_3_256: String
    val registerIdentity_20_160_3_3_736_200_NA: String

    val registerIdentityLight160: String
    val registerIdentityLight224: String
    val registerIdentityLight256: String
    val registerIdentityLight384: String
    val registerIdentityLight512: String

    val registerIdentity_11_256_3_4_336_232_1_1480_4_256: String
    val registerIdentity_11_256_3_3_576_248_NA: String
    val registerIdentity_11_256_3_5_576_248_NA: String
    val registerIdentity_14_256_3_3_576_240_NA: String
    val registerIdentity_14_256_3_4_336_232_1_1480_5_296: String
    val registerIdentity_14_256_3_4_576_248_1_1496_3_256: String
    val registerIdentity_1_256_3_4_576_232_1_1480_3_256: String
    val registerIdentity_1_256_3_5_336_248_1_2120_4_256: String
    val registerIdentity_2_256_3_4_336_232_1_1480_4_256: String
    val registerIdentity_2_256_3_4_336_248_NA: String
    val registerIdentity_20_160_3_2_576_184_NA: String
    val registerIdentity_20_160_3_3_576_200_NA: String
    val registerIdentity_20_256_3_5_336_248_NA: String
    val registerIdentity_23_160_3_3_576_200_NA: String
    val registerIdentity_24_256_3_4_336_248_NA: String
    val registerIdentity_3_256_3_4_600_248_1_1496_3_256: String
    val registerIdentity_6_160_3_3_336_216_1_1080_3_256: String
    val registerIdentity_3_512_3_3_336_264_NA: String


    val registerIdentity_11_256_3_5_584_264_1_2136_4_256: String
    val registerIdentity_11_256_3_5_576_264_NA: String
    val registerIdentity_2_256_3_4_336_248_22_1496_7_2408: String
    val registerIdentity_1_256_3_4_336_232_NA: String

    val registerIdentity_25_384_3_3_336_232_NA: String
    val registerIdentity_25_384_3_4_336_264_1_2904_2_256: String
    val registerIdentity_26_512_3_3_336_248_NA: String

    val registerIdentity_26_512_3_3_336_264_1_1968_2_256: String
    val registerIdentity_27_512_3_4_336_248_NA: String

    val registerIdentity_1_256_3_5_336_248_1_2120_3_256: String
    val registerIdentity_7_160_3_3_336_216_1_1080_3_256: String

    val registerIdentity_8_160_3_3_336_216_1_1080_3_256: String

    val registerIdentity_3_256_3_3_576_248_NA: String

    val registerIdentity_25_384_3_3_336_264_1_2024_3_296: String

    val registerIdentity_28_384_3_3_576_264_24_2024_4_2792: String
    val registerIdentity_1_256_3_6_576_248_1_2432_5_296: String
    val registerIdentity_25_384_3_3_336_248_NA: String

    val registerIdentity_1_160_3_3_576_200_NA: String
    val registerIdentity_1_256_3_3_576_248_NA: String
    val registerIdentity_1_256_3_4_336_232_1_1480_5_296: String
    val registerIdentity_1_256_3_6_336_248_1_2744_4_256: String
    val registerIdentity_2_256_3_6_336_264_1_2448_3_256: String
    val registerIdentity_3_160_3_3_336_200_NA: String

    val registerIdentity_3_160_3_4_576_216_1_1512_3_256: String
    val registerIdentity_11_256_3_2_336_216_NA: String
    val registerIdentity_11_256_3_3_336_248_NA: String

    val registerIdentity_11_256_3_3_576_240_1_864_5_264: String
    val registerIdentity_11_256_3_3_576_248_1_1184_5_264: String
    val registerIdentity_11_256_3_4_584_248_1_1496_4_256: String

    val registerIdentity_11_256_3_5_576_248_1_1808_5_296: String
    val registerIdentity_12_256_3_3_336_232_NA: String
    val registerIdentity_15_512_3_3_336_248_NA: String

    val registerIdentity_21_256_3_3_336_232_NA: String
    val registerIdentity_21_256_3_5_576_232_NA: String
    val registerIdentity_24_256_3_4_336_232_NA: String

    val registerIdentity_11_256_3_5_576_248_1_1808_4_256: String

    val registerIdentity_25_384_3_5_576_248_20_3768_3_2008: String
    val registerIdentity_1_256_3_6_336_248_1_2432_3_256: String
    val registerIdentity_2_256_3_5_336_248_22_1808_7_2408: String

    val registerIdentity_1_256_3_4_336_248_1_1496_4_256: String
    val registerIdentity_11_256_3_4_576_248_1_1496_5_296: String

    val registerIdentity_1_256_3_5_344_232_NA: String
    val registerIdentity_21_256_3_7_336_264_21_3072_6_2008: String

    val registerIdentity_1_256_3_5_336_232_NA: String

    val registerIdentity_1_256_3_7_336_264_20_2760_6_2008: String

    val registerIdentity_1_256_3_4_336_232_1_1480_4_256: String

    val registerIdentity_1_256_3_4_336_248_1_560_4_256: String

    val registerIdentity_26_512_3_2_336_248_1_1384_2_256: String

}

/* TESTNET */
object TestNetConfig : IConfig {
    // RETAINED (Open Decision OD-5): passport registration is anchored on Rarimo's L2 and
    // our verificator-svc validates against that same registration state, so the relayer,
    // RPC, explorer and contract addresses below must keep matching Rarimo's stage
    // deployment. See Open Decision OD-5 before changing any of them - matches iOS Task
    // B1's xcconfig treatment of the same infrastructure.
    override val RELAYER_URL = "https://api.orgs.app.stage.rarime.com"
    override val COSMOS_RPC_URL = "https://rpc-api.node1.mainnet-beta.rarimo.com"
    // STRIPPED (Task C4/C5, points-service): dead - EVM_SERVICE_URL's only DI consumer
    // ("erc20Retrofit" in ManagerModule.kt) has zero @Inject call sites, so this provider
    // is never actually built. "http://NONE" (not "") for consistency with
    // VOTING_RELAYER_URL/VOTING_RPC_URL below, which guard the identical Retrofit/Web3j
    // eager-baseUrl hazard - "" would throw IllegalArgumentException if this provider
    // is ever wired up by a future change.
    override val EVM_SERVICE_URL = "http://NONE"
    // NOT TOUCHED this task (out of Task C4's own file scope): still Rarimo's real
    // community links, user-facing via "Follow us" buttons in Invitation.kt (the
    // enter_program flow, which survives independent of Task C5's module strip per
    // Task C3's finding). Carried forward - Foundation doesn't have its own Discord/
    // Twitter to repoint these to, and TWITTER_URL is live on a screen real users reach.
    override val DISCORD_URL = "https://discord.gg/Bzjm5MDXrU"
    override val TWITTER_URL = "https://x.com/Rarimo_protocol"

    // Foundation-owned.
    override val INVITATION_BASE_URL = "https://foundation-next-app-web.web.app"

    // RETAINED, deliberately NOT blanked despite the "points-service" name (deviation from
    // this task's own brief): AuthManager.login() - the app's core sign-in flow, invoked
    // from MainViewModel.kt and RefreshTokenInterceptor.kt - uses this as the eventID for
    // its ZK login proof against the retained RELAYER_URL/AuthAPIManager. LightProofHandlerViewModel.kt
    // uses it the same way for the retained light-verification flow. Blanking it would send
    // an empty eventID to Rarimo's relayer and break login, not just the points/airdrop
    // features it's named after. Mirrors iOS Task B5's retained UserManager.anonymousIdEventId
    // (renamed from Points.PointsEventId for the same reason).
    override val POINTS_SVC_ID = "0x77fabbc6cb41a11d4fb6918696b3550d5d602f252436dd587f9065b7c4e62b"
    // STRIPPED (points-service/airdrop, Task C5 territory): only consumer is
    // IdentityManager.getUserAirDropNullifier(), which has zero callers anywhere.
    override val AIRDROP_SVC_ID = ""

    override val ICAO_COSMOS_RPC = "core-api.node1.mainnet-beta.rarimo.com:443"
    override val MASTER_CERTIFICATES_FILENAME = "icaopkd-list.ldif"
    override val MASTER_CERTIFICATES_BUCKETNAME = "rarimo-temp"
    override val EVM_STABLE_COIN_RPC = "https://ethereum-sepolia-rpc.publicnode.com"
    override val STABLE_COIN_ADDRESS = "0xbd03f0fC994fd1015eAdc37c943055330e238Ad9"
    override val EXPLORER_API_URL = "https://api.evmscan.rarimo.com"
    override val RARIMO_EXPLORER = "https://api.evmscan.rarimo.com/tx"
    override val EVM_RPC_URL = "https://rpc.evm.mainnet.rarimo.com"
    override val REGISTER_CONTRACT_ADDRESS = "0x435E8833bC8c6F5Fdfc1cd7E45D5760b523f4020"
    override val REGISTRATION_SIMPLE_CONTRACT_ADRRESS = "0xd63782478CA40b587785700Ce49248775398b045"
    override val CERTIFICATES_SMT_CONTRACT_ADDRESS = "0xc2974679359c756bf97ff6B698377E02c083F3D4"
    override val REGISTRATION_SMT_CONTRACT_ADDRESS = "0xF19a85B10d705Ed3bAF3c0eCe3E73d8077Bf6481"
    override val STATE_KEEPER_CONTRACT_ADDRESS = "0x9EDADB216C1971cf0343b8C687cF76E7102584DB"
    // STRIPPED (points-service, Task C5 territory): only consumer is PointsManager.kt.
    override val POINTS_SVC_SELECTOR = ""
    override val POINTS_SVC_ALLOWED_IDENTITY_TIMESTAMP = 0L

    override val FEEDBACK_EMAIL = "support@foundation-global.com"
    override val CHAIN = RarimoChains.MainnetBeta
    override val lightVerificationSKHex = Keys.lightVerificationSKHex
    override val GOOGLE_WEB_KEY = Keys.GOOGLE_WEB_KEY
    override val APP_ID_FIREBASE = Keys.APP_ID


    // Dev/stage tier of the FCM topics, matching iOS Task B1's Development.xcconfig values
    // exactly - both platforms subscribe to the same topics. Android has no separate
    // debug/release xcconfig split; TestNetConfig/MainnetConfig (selected by
    // BuildConfig.isTestnet, pinned false on all default build types per Task C1 and OD-5)
    // is the closest structural analog to iOS's Development/Production split.
    override val GLOBAL_NOTIFICATION_TOPIC = "foundation-dev"
    override val REWARD_NOTIFICATION_TOPIC: String = "foundation-rewardable-dev"

    override val APPSFLYER_DEV_KEY = Keys.APPSFLYER_DEV_KEY

    // STRIPPED (Freedom Tool / Polls, Task C5 territory - OD-4). Not blanked to "":
    // ManagerModule.kt builds a Retrofit client with .baseUrl(VOTING_RELAYER_URL) - OkHttp
    // validates the URL immediately and throws IllegalArgumentException on "" - and
    // Web3j's HttpService(VOTING_RPC_URL) is built the same eager way. "http://NONE" is
    // this codebase's own existing placeholder pattern for an intentionally-unreachable
    // Retrofit base URL (see ManagerModule.kt's EXT_INTEGRATOR retrofit), reused here for
    // consistency and to keep the DI graph constructing until Task C5 removes VotingManager
    // and this provider entirely.
    override val VOTING_RELAYER_URL: String = "http://NONE"
    // STRIPPED (Freedom Tool / Polls, Task C5 territory): consumed only inside
    // VotingManager.kt method bodies (not at construction), so a plain "" is safe here.
    override val VOTING_REGISTRATION_SMT_CONTRACT_ADDRESS: String = ""
    override val VOTING_RPC_URL: String = "http://NONE"

    override val PROPOSAL_CONTRACT_ADDRESS: String = ""
    override val MULTICALL_CONTRACT_ADDRRESS: String = ""

    // STRIPPED (Freedom Tool / Polls, Task C5 territory): opened via LocalUriHandler/browser
    // Intent (FreedomtoolExpandedWidget.kt) - blanking to "" risks an ActivityNotFoundException
    // if tapped before Task C5 removes this widget, so "http://NONE" is used instead.
    override val VOTING_WEBSITE_URL: String = "http://NONE"

    override val NOIR_TRUSTED_SETUP_URL: String =
        "https://storage.googleapis.com/rarimo-store/trusted-setups/ultraPlonkTrustedSetup.dat"


    override val FACE_REGISTRY_ADDRESS: String = "0x3C0f27AC1817820C1BA41337B53090652aE4F448"

    override val GUESS_CELEBRITY_CONTRACT_ADDRESS: String =
        "0x411AA3eF21AdC9e84c60e17451B0732119C8f0c7"


    override val FACE_REGISTRY_ZKEY_URL: String =
        "https://storage.googleapis.com/rarimo-store/zkey/circuit_final.zkey"
    override val FACE_RECOGNITION_MODEL_URL: String =
        "https://storage.googleapis.com/rarimo-store/face-recognition/face-recognition.tflite"


    override val registerIdentity_1_160_3_4_576_200_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits/v0.2.3/registerIdentity_1_160_3_4_576_200_NA-download.zip"


    override val registerIdentity_14_256_3_4_336_64_1_1480_5_296: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits/v0.2.10/registerIdentity_14_256_3_4_336_64_1_1480_5_296-download.zip"

    override val registerIdentity_1_256_3_6_336_560_1_2744_4_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits/v0.2.11/registerIdentity_1_256_3_6_336_560_1_2744_4_256-download.zip"
    override val registerIdentity_20_256_3_5_336_72_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits/v0.2.11/registerIdentity_20_256_3_5_336_72_NA-download.zip"

    override val registerIdentity_4_160_3_3_336_216_1_1296_3_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits/v0.2.12/registerIdentity_4_160_3_3_336_216_1_1296_3_256-download.zip"
    override val registerIdentity_20_160_3_3_736_200_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits/v0.2.12/registerIdentity_20_160_3_3_736_200_NA-download.zip"


    override val registerIdentityLight160: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits/v0.2.6-light/registerIdentityLight160-download.zip"
    override val registerIdentityLight224: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits/v0.2.6-light/registerIdentityLight224-download.zip"
    override val registerIdentityLight256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits/v0.2.6-light/registerIdentityLight256-download.zip"
    override val registerIdentityLight384: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits/v0.2.6-light/registerIdentityLight384-download.zip"
    override val registerIdentityLight512: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits/v0.2.6-light/registerIdentityLight512-download.zip"


    override val registerIdentity_10_256_3_3_576_248_1_1184_5_264: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v1.0.4/registerIdentity_10_256_3_3_576_248_1_1184_5_264.json"
    override val registerIdentity_11_256_3_3_576_248_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.10-fix/registerIdentity_11_256_3_3_576_248_NA.json"
    override val registerIdentity_11_256_3_4_336_232_1_1480_4_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.6-fix/registerIdentity_11_256_3_4_336_232_1_1480_4_256.json"
    override val registerIdentity_11_256_3_5_576_248_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.12-fix/registerIdentity_11_256_3_5_576_248_NA.json"
    override val registerIdentity_14_256_3_3_576_240_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.8-fix/registerIdentity_14_256_3_3_576_240_NA.json"
    override val registerIdentity_14_256_3_4_336_232_1_1480_5_296: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.12-fix/registerIdentity_14_256_3_4_336_232_1_1480_5_296.json"
    override val registerIdentity_14_256_3_4_576_248_1_1496_3_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.8-fix/registerIdentity_14_256_3_4_576_248_1_1496_3_256.json"
    override val registerIdentity_1_256_3_4_576_232_1_1480_3_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.12-fix/registerIdentity_1_256_3_4_576_232_1_1480_3_256.json"
    override val registerIdentity_1_256_3_4_600_248_1_1496_3_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v1.0.4/registerIdentity_1_256_3_4_600_248_1_1496_3_256.json"
    override val registerIdentity_1_256_3_5_336_248_1_2120_4_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.7-fix/registerIdentity_1_256_3_5_336_248_1_2120_4_256.json"
    override val registerIdentity_2_256_3_4_336_232_1_1480_4_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.7-fix/registerIdentity_2_256_3_4_336_232_1_1480_4_256.json"
    override val registerIdentity_2_256_3_4_336_248_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.7-fix/registerIdentity_2_256_3_4_336_248_NA.json"
    override val registerIdentity_20_160_3_2_576_184_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.8-fix/registerIdentity_20_160_3_2_576_184_NA.json"
    override val registerIdentity_20_160_3_3_576_200_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.9-fix/registerIdentity_20_160_3_3_576_200_NA.json"
    override val registerIdentity_20_256_3_5_336_248_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.11-fix/registerIdentity_20_256_3_5_336_248_NA.json"
    override val registerIdentity_21_256_3_3_576_232_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v1.0.4/registerIdentity_21_256_3_3_576_232_NA.json"
    override val registerIdentity_23_160_3_3_576_200_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.10-fix/registerIdentity_23_160_3_3_576_200_NA.json"
    override val registerIdentity_24_256_3_4_336_248_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.11-fix/registerIdentity_24_256_3_4_336_248_NA.json"
    override val registerIdentity_3_256_3_4_600_248_1_1496_3_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.10-fix/registerIdentity_3_256_3_4_600_248_1_1496_3_256.json"
    override val registerIdentity_3_512_3_3_336_264_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.6-fix/registerIdentity_3_512_3_3_336_264_NA.json"

    override val registerIdentity_6_160_3_3_336_216_1_1080_3_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.11-fix/registerIdentity_6_160_3_3_336_216_1_1080_3_256.json"
    override val registerIdentity_1_256_3_5_576_248_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.9-fix/registerIdentity_1_256_3_5_576_248_NA.json"
    override val registerIdentity_1_256_3_6_576_264_1_2448_3_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.9-fix/registerIdentity_1_256_3_6_576_264_1_2448_3_256.json"
    override val registerIdentity_2_256_3_6_336_264_21_2448_6_2008: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.3/registerIdentity_2_256_3_6_336_264_21_2448_6_2008.json"
    override val registerIdentity_2_256_3_6_336_248_1_2432_3_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.3/registerIdentity_2_256_3_6_336_248_1_2432_3_256.json"
    override val registerIdentity_2_256_3_6_576_248_1_2432_3_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.6-fix/registerIdentity_2_256_3_6_576_248_1_2432_3_256.json"
    override val registerIdentity_20_256_3_3_336_224_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.3/registerIdentity_20_256_3_3_336_224_NA.json"
    override val registerIdentity_21_256_3_4_576_232_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.5-fix/registerIdentity_21_256_3_4_576_232_NA.json"


    override val registerIdentity_11_256_3_5_584_264_1_2136_4_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.13/registerIdentity_11_256_3_5_584_264_1_2136_4_256.json"

    override val registerIdentity_11_256_3_5_576_264_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.13/registerIdentity_11_256_3_5_576_264_NA.json"

    override val registerIdentity_2_256_3_4_336_248_22_1496_7_2408: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.14/registerIdentity_2_256_3_4_336_248_22_1496_7_2408.json"

    override val registerIdentity_1_256_3_4_336_232_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.14/registerIdentity_1_256_3_4_336_232_NA.json"

    override val registerIdentity_25_384_3_3_336_232_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.15/registerIdentity_25_384_3_3_336_232_NA.json"
    override val registerIdentity_25_384_3_4_336_264_1_2904_2_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.15/registerIdentity_25_384_3_4_336_264_1_2904_2_256.json"
    override val registerIdentity_26_512_3_3_336_248_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.15/registerIdentity_26_512_3_3_336_248_NA.json"
    override val registerIdentity_26_512_3_3_336_264_1_1968_2_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.16/registerIdentity_26_512_3_3_336_264_1_1968_2_256.json"
    override val registerIdentity_27_512_3_4_336_248_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.16/registerIdentity_27_512_3_4_336_248_NA.json"

    override val registerIdentity_1_256_3_5_336_248_1_2120_3_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.18/registerIdentity_1_256_3_5_336_248_1_2120_3_256.json"
    override val registerIdentity_7_160_3_3_336_216_1_1080_3_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.18/registerIdentity_7_160_3_3_336_216_1_1080_3_256.json"

    override val registerIdentity_8_160_3_3_336_216_1_1080_3_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.19/registerIdentity_8_160_3_3_336_216_1_1080_3_256.json"

    override val registerIdentity_3_256_3_3_576_248_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.20/registerIdentity_3_256_3_3_576_248_NA.json"

    override val registerIdentity_25_384_3_3_336_264_1_2024_3_296: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.21/registerIdentity_25_384_3_3_336_264_1_2024_3_296.json"

    override val registerIdentity_28_384_3_3_576_264_24_2024_4_2792: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.22/registerIdentity_28_384_3_3_576_264_24_2024_4_2792.json"
    override val registerIdentity_1_256_3_6_576_248_1_2432_5_296: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.22/registerIdentity_1_256_3_6_576_248_1_2432_5_296.json"
    override val registerIdentity_25_384_3_3_336_248_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.22/registerIdentity_25_384_3_3_336_248_NA.json"

    override val registerIdentity_1_160_3_3_576_200_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.23/registerIdentity_1_160_3_3_576_200_NA.json"
    override val registerIdentity_1_256_3_3_576_248_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.23/registerIdentity_1_256_3_3_576_248_NA.json"
    override val registerIdentity_1_256_3_4_336_232_1_1480_5_296: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.23/registerIdentity_1_256_3_4_336_232_1_1480_5_296.json"

    override val registerIdentity_1_256_3_6_336_248_1_2744_4_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.24/registerIdentity_1_256_3_6_336_248_1_2744_4_256.json"
    override val registerIdentity_2_256_3_6_336_264_1_2448_3_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.24/registerIdentity_2_256_3_6_336_264_1_2448_3_256.json"
    override val registerIdentity_3_160_3_3_336_200_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.24/registerIdentity_3_160_3_3_336_200_NA.json"

    override val registerIdentity_3_160_3_4_576_216_1_1512_3_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.25/registerIdentity_3_160_3_4_576_216_1_1512_3_256.json"
    override val registerIdentity_11_256_3_2_336_216_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.25/registerIdentity_11_256_3_2_336_216_NA.json"
    override val registerIdentity_11_256_3_3_336_248_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.25/registerIdentity_11_256_3_3_336_248_NA.json"

    override val registerIdentity_11_256_3_3_576_240_1_864_5_264: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.26/registerIdentity_11_256_3_3_576_240_1_864_5_264.json"
    override val registerIdentity_11_256_3_3_576_248_1_1184_5_264: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.26/registerIdentity_11_256_3_3_576_248_1_1184_5_264.json"
    override val registerIdentity_11_256_3_4_584_248_1_1496_4_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.26/registerIdentity_11_256_3_4_584_248_1_1496_4_256.json"

    override val registerIdentity_11_256_3_5_576_248_1_1808_5_296: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.27/registerIdentity_11_256_3_5_576_248_1_1808_5_296.json"
    override val registerIdentity_12_256_3_3_336_232_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.27/registerIdentity_12_256_3_3_336_232_NA.json"
    override val registerIdentity_15_512_3_3_336_248_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.27/registerIdentity_15_512_3_3_336_248_NA.json"

    override val registerIdentity_21_256_3_3_336_232_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.28/registerIdentity_21_256_3_3_336_232_NA.json"
    override val registerIdentity_21_256_3_5_576_232_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.28/registerIdentity_21_256_3_5_576_232_NA.json"
    override val registerIdentity_24_256_3_4_336_232_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.28/registerIdentity_24_256_3_4_336_232_NA.json"

    override val registerIdentity_11_256_3_5_576_248_1_1808_4_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.29/registerIdentity_11_256_3_5_576_248_1_1808_4_256.json"

    override val registerIdentity_25_384_3_5_576_248_20_3768_3_2008: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.30/registerIdentity_25_384_3_5_576_248_20_3768_3_2008.json"
    override val registerIdentity_1_256_3_6_336_248_1_2432_3_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.30/registerIdentity_1_256_3_6_336_248_1_2432_3_256.json"
    override val registerIdentity_2_256_3_5_336_248_22_1808_7_2408: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.30/registerIdentity_2_256_3_5_336_248_22_1808_7_2408.json"

    override val registerIdentity_1_256_3_4_336_248_1_1496_4_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.31/registerIdentity_1_256_3_4_336_248_1_1496_4_256.json"
    override val registerIdentity_11_256_3_4_576_248_1_1496_5_296: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.31/registerIdentity_11_256_3_4_576_248_1_1496_5_296.json"

    override val registerIdentity_1_256_3_5_344_232_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.32/registerIdentity_1_256_3_5_344_232_NA.json"
    override val registerIdentity_21_256_3_7_336_264_21_3072_6_2008: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.32/registerIdentity_21_256_3_7_336_264_21_3072_6_2008.json"

    override val registerIdentity_1_256_3_5_336_232_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.33/registerIdentity_1_256_3_5_336_232_NA.json"

    override val registerIdentity_1_256_3_7_336_264_20_2760_6_2008: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.34/registerIdentity_1_256_3_7_336_264_20_2760_6_2008.json"

    override val registerIdentity_1_256_3_4_336_232_1_1480_4_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.36/registerIdentity_1_256_3_4_336_232_1_1480_4_256.json"

    override val registerIdentity_1_256_3_4_336_248_1_560_4_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.37/registerIdentity_1_256_3_4_336_248_1_560_4_256.json"

    override val registerIdentity_26_512_3_2_336_248_1_1384_2_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.38/registerIdentity_26_512_3_2_336_248_1_1384_2_256.json"


}

// Mainnet
object MainnetConfig : IConfig {
    // RETAINED (Open Decision OD-5): see the matching comment on TestNetConfig above -
    // same rationale, mainnet deployment. Matches iOS Task B1's Production.xcconfig.
    override val RELAYER_URL = "https://api.app.rarime.com"
    override val EVM_RPC_URL = "https://l2.rarimo.com"
    override val COSMOS_RPC_URL = "https://rpc-api.mainnet.rarimo.com"
    // STRIPPED (points-service): see TestNetConfig - dead, zero DI consumers.
    // "http://NONE" for consistency with VOTING_RELAYER_URL/VOTING_RPC_URL's
    // eager-baseUrl hazard guard below.
    override val EVM_SERVICE_URL = "http://NONE"
    // NOT TOUCHED this task (out of Task C4's own file scope): still Rarimo's real
    // community links, user-facing via "Follow us" buttons in Invitation.kt (the
    // enter_program flow, which survives independent of Task C5's module strip per
    // Task C3's finding). Carried forward - Foundation doesn't have its own Discord/
    // Twitter to repoint these to, and TWITTER_URL is live on a screen real users reach.
    override val DISCORD_URL = "https://discord.gg/Bzjm5MDXrU"
    override val TWITTER_URL = "https://x.com/Rarimo_protocol"

    // Foundation-owned.
    override val INVITATION_BASE_URL = "https://foundation-next-app-web.web.app"

    // RETAINED: see the matching comment on TestNetConfig above - feeds AuthManager.login()'s
    // core sign-in ZK proof (and LightProofHandlerViewModel.kt's light-verification flow),
    // not just the points/airdrop features it's named after.
    override val POINTS_SVC_ID = "0x77fabbc6cb41a11d4fb6918696b3550d5d602f252436dd587f9065b7c4e62b"
    // STRIPPED (points-service/airdrop): see TestNetConfig - zero live callers.
    override val AIRDROP_SVC_ID = ""

    override val ICAO_COSMOS_RPC = "core-api.mainnet.rarimo.com:443"
    override val MASTER_CERTIFICATES_FILENAME = "icaopkd-list.ldif"
    override val MASTER_CERTIFICATES_BUCKETNAME = "rarimo-temp"
    override val EVM_STABLE_COIN_RPC = "https://ethereum-sepolia-rpc.publicnode.com"

    override val REGISTER_CONTRACT_ADDRESS = "0x11BB4B14AA6e4b836580F3DBBa741dD89423B971"
    override val STABLE_COIN_ADDRESS = "0xbd03f0fC994fd1015eAdc37c943055330e238Ad9"
    override val EXPLORER_API_URL = "https://evmscan.l2.rarimo.com"
    override val CERTIFICATES_SMT_CONTRACT_ADDRESS = "0xA8b350d699632569D5351B20ffC1b31202AcEDD8"
    override val REGISTRATION_SMT_CONTRACT_ADDRESS = "0x479F84502Db545FA8d2275372E0582425204A879"
    override val STATE_KEEPER_CONTRACT_ADDRESS = "0x61aa5b68D811884dA4FEC2De4a7AA0464df166E1"
    override val REGISTRATION_SIMPLE_CONTRACT_ADRRESS = "0x497D6957729d3a39D43843BD27E6cbD12310F273"

    // STRIPPED (points-service): see TestNetConfig - only consumer is PointsManager.kt.
    override val POINTS_SVC_SELECTOR = ""
    override val POINTS_SVC_ALLOWED_IDENTITY_TIMESTAMP = 0L
    override val FEEDBACK_EMAIL = "support@foundation-global.com"
    override val CHAIN = RarimoChains.Mainnet
    override val lightVerificationSKHex = Keys.lightVerificationSKHex
    override val GOOGLE_WEB_KEY = Keys.GOOGLE_WEB_KEY
    override val APP_ID_FIREBASE = Keys.APP_ID
    override val RARIMO_EXPLORER = "https://scan.rarimo.com/tx"
    // Production tier of the FCM topics, matching iOS Task B1's Production.xcconfig values
    // exactly - both platforms subscribe to the same topics.
    override val GLOBAL_NOTIFICATION_TOPIC = "foundation"
    override val REWARD_NOTIFICATION_TOPIC: String = "foundation-rewardable"
    override val APPSFLYER_DEV_KEY = Keys.APPSFLYER_DEV_KEY

    // STRIPPED (Freedom Tool / Polls): see TestNetConfig for the "http://NONE" placeholder
    // rationale (Retrofit/Web3j eager-parse-at-construction crash risk).
    override val VOTING_WEBSITE_URL = "http://NONE"
    override val VOTING_RELAYER_URL: String = "http://NONE"
    override val VOTING_REGISTRATION_SMT_CONTRACT_ADDRESS: String = ""
    override val VOTING_RPC_URL: String = "http://NONE"
    override val PROPOSAL_CONTRACT_ADDRESS: String = ""
    override val MULTICALL_CONTRACT_ADDRRESS: String = ""

    override val FACE_REGISTRY_ADDRESS: String = "0x15DCd57B70D97F1D1F220ccb4e6B8E886aF3e3B9"


    override val GUESS_CELEBRITY_CONTRACT_ADDRESS: String =
        "0x5283f7B6A011433A6631701875A6f147e5c17a96"


    override val FACE_REGISTRY_ZKEY_URL: String =
        "https://storage.googleapis.com/rarimo-store/zkey/circuit_final.zkey"

    override val FACE_RECOGNITION_MODEL_URL: String =
        "https://storage.googleapis.com/rarimo-store/face-recognition/face-recognition.tflite"

    override val NOIR_TRUSTED_SETUP_URL: String =
        "https://storage.googleapis.com/rarimo-store/trusted-setups/ultraPlonkTrustedSetup.dat"

    override val registerIdentity_1_160_3_4_576_200_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits/v0.2.3/registerIdentity_1_160_3_4_576_200_NA-download.zip"


    override val registerIdentity_14_256_3_4_336_64_1_1480_5_296: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits/v0.2.10/registerIdentity_14_256_3_4_336_64_1_1480_5_296-download.zip"

    override val registerIdentity_1_256_3_6_336_560_1_2744_4_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits/v0.2.11/registerIdentity_1_256_3_6_336_560_1_2744_4_256-download.zip"
    override val registerIdentity_20_256_3_5_336_72_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits/v0.2.11/registerIdentity_20_256_3_5_336_72_NA-download.zip"

    override val registerIdentity_4_160_3_3_336_216_1_1296_3_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits/v0.2.12/registerIdentity_4_160_3_3_336_216_1_1296_3_256-download.zip"
    override val registerIdentity_20_160_3_3_736_200_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits/v0.2.12/registerIdentity_20_160_3_3_736_200_NA-download.zip"


    override val registerIdentity_10_256_3_3_576_248_1_1184_5_264: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v1.0.4/registerIdentity_10_256_3_3_576_248_1_1184_5_264.json"
    override val registerIdentity_11_256_3_3_576_248_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.10-fix/registerIdentity_11_256_3_3_576_248_NA.json"
    override val registerIdentity_11_256_3_4_336_232_1_1480_4_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.6-fix/registerIdentity_11_256_3_4_336_232_1_1480_4_256.json"
    override val registerIdentity_11_256_3_5_576_248_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.12-fix/registerIdentity_11_256_3_5_576_248_NA.json"
    override val registerIdentity_14_256_3_3_576_240_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.8-fix/registerIdentity_14_256_3_3_576_240_NA.json"
    override val registerIdentity_14_256_3_4_336_232_1_1480_5_296: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.12-fix/registerIdentity_14_256_3_4_336_232_1_1480_5_296.json"
    override val registerIdentity_14_256_3_4_576_248_1_1496_3_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.8-fix/registerIdentity_14_256_3_4_576_248_1_1496_3_256.json"
    override val registerIdentity_1_256_3_4_576_232_1_1480_3_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.12-fix/registerIdentity_1_256_3_4_576_232_1_1480_3_256.json"
    override val registerIdentity_1_256_3_4_600_248_1_1496_3_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v1.0.4/registerIdentity_1_256_3_4_600_248_1_1496_3_256.json"
    override val registerIdentity_1_256_3_5_336_248_1_2120_4_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.7-fix/registerIdentity_1_256_3_5_336_248_1_2120_4_256.json"
    override val registerIdentity_2_256_3_4_336_232_1_1480_4_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.7-fix/registerIdentity_2_256_3_4_336_232_1_1480_4_256.json"
    override val registerIdentity_2_256_3_4_336_248_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.7-fix/registerIdentity_2_256_3_4_336_248_NA.json"
    override val registerIdentity_20_160_3_2_576_184_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.8-fix/registerIdentity_20_160_3_2_576_184_NA.json"
    override val registerIdentity_20_160_3_3_576_200_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.9-fix/registerIdentity_20_160_3_3_576_200_NA.json"
    override val registerIdentity_20_256_3_5_336_248_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.11-fix/registerIdentity_20_256_3_5_336_248_NA.json"
    override val registerIdentity_21_256_3_3_576_232_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v1.0.4/registerIdentity_21_256_3_3_576_232_NA.json"
    override val registerIdentity_23_160_3_3_576_200_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.10-fix/registerIdentity_23_160_3_3_576_200_NA.json"
    override val registerIdentity_24_256_3_4_336_248_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.11-fix/registerIdentity_24_256_3_4_336_248_NA.json"
    override val registerIdentity_3_256_3_4_600_248_1_1496_3_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.10-fix/registerIdentity_3_256_3_4_600_248_1_1496_3_256.json"
    override val registerIdentity_3_512_3_3_336_264_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.6-fix/registerIdentity_3_512_3_3_336_264_NA.json"
    override val registerIdentity_6_160_3_3_336_216_1_1080_3_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.11-fix/registerIdentity_6_160_3_3_336_216_1_1080_3_256.json"

    override val registerIdentity_1_256_3_5_576_248_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.9-fix/registerIdentity_1_256_3_5_576_248_NA.json"
    override val registerIdentity_1_256_3_6_576_264_1_2448_3_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.9-fix/registerIdentity_1_256_3_6_576_264_1_2448_3_256.json"
    override val registerIdentity_2_256_3_6_336_264_21_2448_6_2008: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.3/registerIdentity_2_256_3_6_336_264_21_2448_6_2008.json"
    override val registerIdentity_2_256_3_6_336_248_1_2432_3_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.3/registerIdentity_2_256_3_6_336_248_1_2432_3_256.json"
    override val registerIdentity_2_256_3_6_576_248_1_2432_3_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.6-fix/registerIdentity_2_256_3_6_576_248_1_2432_3_256.json"
    override val registerIdentity_20_256_3_3_336_224_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.3/registerIdentity_20_256_3_3_336_224_NA.json"
    override val registerIdentity_21_256_3_4_576_232_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.5-fix/registerIdentity_21_256_3_4_576_232_NA.json"


    override val registerIdentity_11_256_3_5_584_264_1_2136_4_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.13/registerIdentity_11_256_3_5_584_264_1_2136_4_256.json"

    override val registerIdentity_11_256_3_5_576_264_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.13/registerIdentity_11_256_3_5_576_264_NA.json"

    override val registerIdentity_2_256_3_4_336_248_22_1496_7_2408: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.14/registerIdentity_2_256_3_4_336_248_22_1496_7_2408.json"

    override val registerIdentity_1_256_3_4_336_232_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.14/registerIdentity_1_256_3_4_336_232_NA.json"

    override val registerIdentity_25_384_3_3_336_232_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.15/registerIdentity_25_384_3_3_336_232_NA.json"
    override val registerIdentity_25_384_3_4_336_264_1_2904_2_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.15/registerIdentity_25_384_3_4_336_264_1_2904_2_256.json"
    override val registerIdentity_26_512_3_3_336_248_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.15/registerIdentity_26_512_3_3_336_248_NA.json"


    override val registerIdentityLight160: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits/v0.2.6-light/registerIdentityLight160-download.zip"
    override val registerIdentityLight224: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits/v0.2.6-light/registerIdentityLight224-download.zip"
    override val registerIdentityLight256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits/v0.2.6-light/registerIdentityLight256-download.zip"
    override val registerIdentityLight384: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits/v0.2.6-light/registerIdentityLight384-download.zip"
    override val registerIdentityLight512: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits/v0.2.6-light/registerIdentityLight512-download.zip"


    override val registerIdentity_26_512_3_3_336_264_1_1968_2_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.16/registerIdentity_26_512_3_3_336_264_1_1968_2_256.json"
    override val registerIdentity_27_512_3_4_336_248_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.16/registerIdentity_27_512_3_4_336_248_NA.json"

    override val registerIdentity_1_256_3_5_336_248_1_2120_3_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.18/registerIdentity_1_256_3_5_336_248_1_2120_3_256.json"
    override val registerIdentity_7_160_3_3_336_216_1_1080_3_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.18/registerIdentity_7_160_3_3_336_216_1_1080_3_256.json"

    override val registerIdentity_8_160_3_3_336_216_1_1080_3_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.19/registerIdentity_8_160_3_3_336_216_1_1080_3_256.json"

    override val registerIdentity_3_256_3_3_576_248_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.20/registerIdentity_3_256_3_3_576_248_NA.json"

    override val registerIdentity_25_384_3_3_336_264_1_2024_3_296: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.21/registerIdentity_25_384_3_3_336_264_1_2024_3_296.json"

    override val registerIdentity_28_384_3_3_576_264_24_2024_4_2792: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.22/registerIdentity_28_384_3_3_576_264_24_2024_4_2792.json"
    override val registerIdentity_1_256_3_6_576_248_1_2432_5_296: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.22/registerIdentity_1_256_3_6_576_248_1_2432_5_296.json"
    override val registerIdentity_25_384_3_3_336_248_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.22/registerIdentity_25_384_3_3_336_248_NA.json"

    override val registerIdentity_1_160_3_3_576_200_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.23/registerIdentity_1_160_3_3_576_200_NA.json"
    override val registerIdentity_1_256_3_3_576_248_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.23/registerIdentity_1_256_3_3_576_248_NA.json"
    override val registerIdentity_1_256_3_4_336_232_1_1480_5_296: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.23/registerIdentity_1_256_3_4_336_232_1_1480_5_296.json"

    override val registerIdentity_1_256_3_6_336_248_1_2744_4_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.24/registerIdentity_1_256_3_6_336_248_1_2744_4_256.json"
    override val registerIdentity_2_256_3_6_336_264_1_2448_3_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.24/registerIdentity_2_256_3_6_336_264_1_2448_3_256.json"
    override val registerIdentity_3_160_3_3_336_200_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.24/registerIdentity_3_160_3_3_336_200_NA.json"

    override val registerIdentity_3_160_3_4_576_216_1_1512_3_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.25/registerIdentity_3_160_3_4_576_216_1_1512_3_256.json"
    override val registerIdentity_11_256_3_2_336_216_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.25/registerIdentity_11_256_3_2_336_216_NA.json"
    override val registerIdentity_11_256_3_3_336_248_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.25/registerIdentity_11_256_3_3_336_248_NA.json"

    override val registerIdentity_11_256_3_3_576_240_1_864_5_264: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.26/registerIdentity_11_256_3_3_576_240_1_864_5_264.json"
    override val registerIdentity_11_256_3_3_576_248_1_1184_5_264: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.26/registerIdentity_11_256_3_3_576_248_1_1184_5_264.json"
    override val registerIdentity_11_256_3_4_584_248_1_1496_4_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.26/registerIdentity_11_256_3_4_584_248_1_1496_4_256.json"

    override val registerIdentity_11_256_3_5_576_248_1_1808_5_296: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.27/registerIdentity_11_256_3_5_576_248_1_1808_5_296.json"
    override val registerIdentity_12_256_3_3_336_232_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.27/registerIdentity_12_256_3_3_336_232_NA.json"
    override val registerIdentity_15_512_3_3_336_248_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.27/registerIdentity_15_512_3_3_336_248_NA.json"

    override val registerIdentity_21_256_3_3_336_232_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.28/registerIdentity_21_256_3_3_336_232_NA.json"
    override val registerIdentity_21_256_3_5_576_232_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.28/registerIdentity_21_256_3_5_576_232_NA.json"
    override val registerIdentity_24_256_3_4_336_232_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.28/registerIdentity_24_256_3_4_336_232_NA.json"

    override val registerIdentity_11_256_3_5_576_248_1_1808_4_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.29/registerIdentity_11_256_3_5_576_248_1_1808_4_256.json"

    override val registerIdentity_25_384_3_5_576_248_20_3768_3_2008: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.30/registerIdentity_25_384_3_5_576_248_20_3768_3_2008.json"
    override val registerIdentity_1_256_3_6_336_248_1_2432_3_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.30/registerIdentity_1_256_3_6_336_248_1_2432_3_256.json"
    override val registerIdentity_2_256_3_5_336_248_22_1808_7_2408: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.30/registerIdentity_2_256_3_5_336_248_22_1808_7_2408.json"

    override val registerIdentity_1_256_3_4_336_248_1_1496_4_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.31/registerIdentity_1_256_3_4_336_248_1_1496_4_256.json"
    override val registerIdentity_11_256_3_4_576_248_1_1496_5_296: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.31/registerIdentity_11_256_3_4_576_248_1_1496_5_296.json"

    override val registerIdentity_1_256_3_5_344_232_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.32/registerIdentity_1_256_3_5_344_232_NA.json"
    override val registerIdentity_21_256_3_7_336_264_21_3072_6_2008: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.32/registerIdentity_21_256_3_7_336_264_21_3072_6_2008.json"

    override val registerIdentity_1_256_3_5_336_232_NA: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.33/registerIdentity_1_256_3_5_336_232_NA.json"

    override val registerIdentity_1_256_3_7_336_264_20_2760_6_2008: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.34/registerIdentity_1_256_3_7_336_264_20_2760_6_2008.json"

    override val registerIdentity_1_256_3_4_336_232_1_1480_4_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.36/registerIdentity_1_256_3_4_336_232_1_1480_4_256.json"

    override val registerIdentity_1_256_3_4_336_248_1_560_4_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.37/registerIdentity_1_256_3_4_336_248_1_560_4_256.json"

    override val registerIdentity_26_512_3_2_336_248_1_1384_2_256: String =
        "https://storage.googleapis.com/rarimo-store/passport-zk-circuits-noir/v0.1.38/registerIdentity_26_512_3_2_336_248_1_1384_2_256.json"

}
