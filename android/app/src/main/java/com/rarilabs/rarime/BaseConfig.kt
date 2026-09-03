package com.rarilabs.rarime

import com.rarilabs.rarime.config.Keys
import com.rarilabs.rarime.data.RarimoChains

val BaseConfig: IConfig = if (BuildConfig.isTestnet) TestNetConfig else MainnetConfig

interface IConfig {
    val RELAYER_URL: String
    val EVM_RPC_URL: String
    val COSMOS_RPC_URL: String
    val POINTS_SVC_ID: String
    val ICAO_COSMOS_RPC: String
    val MASTER_CERTIFICATES_FILENAME: String
    val MASTER_CERTIFICATES_BUCKETNAME: String
    val REGISTER_CONTRACT_ADDRESS: String
    val CERTIFICATES_SMT_CONTRACT_ADDRESS: String
    val REGISTRATION_SMT_CONTRACT_ADDRESS: String
    val STATE_KEEPER_CONTRACT_ADDRESS: String
    val REGISTRATION_SIMPLE_CONTRACT_ADRRESS: String
    val FEEDBACK_EMAIL: String
    val CHAIN: RarimoChains
    val GLOBAL_NOTIFICATION_TOPIC: String
    val GOOGLE_WEB_KEY: String
    val APP_ID_FIREBASE: String
    // STRIPPED (Task C5 real merge finding, controller correction): REWARD_NOTIFICATION_TOPIC,
    // RARIMO_EXPLORER and APPSFLYER_DEV_KEY were deliberately removed by Task C5 - their sole
    // real consumers (NotificationService.kt's rewards-topic subscribe, WalletTransactionCard.kt,
    // MainActivity.kt's AppsFlyer init) are gone along with the earn/wallet modules and AppsFlyer
    // integration. An earlier merge-conflict resolution incorrectly restored these three as
    // "C4 fixes worth preserving" - they were not; only GLOBAL_NOTIFICATION_TOPIC actually needed
    // preserving. Left as a comment rather than silently deleted so this isn't rediscovered again.








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
    // STRIPPED (Task C5, real merge finding): EVM_SERVICE_URL confirmed zero DI
    // consumers regardless of enter_program's fate. DISCORD_URL/TWITTER_URL/
    // INVITATION_BASE_URL were carried forward by Task C4 as "still needed by
    // Invitation.kt in the enter_program flow" - Task C5's own investigation found
    // ui/components/enter_program/ is ALREADY dead code (its only mount route,
    // Screen.Main.Rewards, is never registered as a composable()), so these three
    // lost their sole real consumer too. All four removed together.

    // RETAINED, deliberately NOT blanked despite the "points-service" name (deviation from
    // this task's own brief): AuthManager.login() - the app's core sign-in flow, invoked
    // from MainViewModel.kt and RefreshTokenInterceptor.kt - uses this as the eventID for
    // its ZK login proof against the retained RELAYER_URL/AuthAPIManager. LightProofHandlerViewModel.kt
    // uses it the same way for the retained light-verification flow. Blanking it would send
    // an empty eventID to Rarimo's relayer and break login, not just the points/airdrop
    // features it's named after. Mirrors iOS Task B5's retained UserManager.anonymousIdEventId
    // (renamed from Points.PointsEventId for the same reason).
    override val POINTS_SVC_ID = "0x77fabbc6cb41a11d4fb6918696b3550d5d602f252436dd587f9065b7c4e62b"
    // STRIPPED (Task C5): IdentityManager.getUserAirDropNullifier() had zero callers.

    override val ICAO_COSMOS_RPC = "core-api.node1.mainnet-beta.rarimo.com:443"
    override val MASTER_CERTIFICATES_FILENAME = "icaopkd-list.ldif"
    override val MASTER_CERTIFICATES_BUCKETNAME = "rarimo-temp"
    override val EVM_RPC_URL = "https://rpc.evm.mainnet.rarimo.com"
    override val REGISTER_CONTRACT_ADDRESS = "0x435E8833bC8c6F5Fdfc1cd7E45D5760b523f4020"
    override val REGISTRATION_SIMPLE_CONTRACT_ADRRESS = "0xd63782478CA40b587785700Ce49248775398b045"
    override val CERTIFICATES_SMT_CONTRACT_ADDRESS = "0xc2974679359c756bf97ff6B698377E02c083F3D4"
    override val REGISTRATION_SMT_CONTRACT_ADDRESS = "0xF19a85B10d705Ed3bAF3c0eCe3E73d8077Bf6481"
    override val STATE_KEEPER_CONTRACT_ADDRESS = "0x9EDADB216C1971cf0343b8C687cF76E7102584DB"
    // STRIPPED (Task C5): PointsManager.kt, the only consumer, is deleted.

    override val FEEDBACK_EMAIL = "support@foundation-global.com"
    override val CHAIN = RarimoChains.MainnetBeta
    override val GOOGLE_WEB_KEY = Keys.GOOGLE_WEB_KEY
    override val APP_ID_FIREBASE = Keys.APP_ID


    // Dev/stage tier of the global FCM topic, matching iOS Task B1's Development.xcconfig
    // value exactly - both platforms subscribe to the same topic. Android has no separate
    // debug/release xcconfig split; TestNetConfig/MainnetConfig (selected by
    // BuildConfig.isTestnet, pinned false on all default build types per Task C1 and OD-5)
    // is the closest structural analog to iOS's Development/Production split. (Task C5's
    // worktree branched before this Task C4 fix landed on main and still had the old
    // "rarime-stage" value in its own copy - this merge keeps C4's real rebrand.)
    override val GLOBAL_NOTIFICATION_TOPIC = "foundation-dev"
    // STRIPPED (Task C5, controller correction): REWARD_NOTIFICATION_TOPIC's only consumer,
    // NotificationService.kt's rewards-topic subscribe call, is gone with the earn module.


    // STRIPPED (Task C5): Freedom Tool / Polls / VotingManager.kt deleted entirely.

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
    // STRIPPED (Task C5): see TestNetConfig - enter_program (Invitation.kt) confirmed dead.

    // RETAINED: see the matching comment on TestNetConfig above - feeds AuthManager.login()'s
    // core sign-in ZK proof (and LightProofHandlerViewModel.kt's light-verification flow),
    // not just the points/airdrop features it's named after.
    override val POINTS_SVC_ID = "0x77fabbc6cb41a11d4fb6918696b3550d5d602f252436dd587f9065b7c4e62b"
    // STRIPPED (Task C5): see TestNetConfig - zero live callers.

    override val ICAO_COSMOS_RPC = "core-api.mainnet.rarimo.com:443"
    override val MASTER_CERTIFICATES_FILENAME = "icaopkd-list.ldif"
    override val MASTER_CERTIFICATES_BUCKETNAME = "rarimo-temp"

    override val REGISTER_CONTRACT_ADDRESS = "0x11BB4B14AA6e4b836580F3DBBa741dD89423B971"
    override val CERTIFICATES_SMT_CONTRACT_ADDRESS = "0xA8b350d699632569D5351B20ffC1b31202AcEDD8"
    override val REGISTRATION_SMT_CONTRACT_ADDRESS = "0x479F84502Db545FA8d2275372E0582425204A879"
    override val STATE_KEEPER_CONTRACT_ADDRESS = "0x61aa5b68D811884dA4FEC2De4a7AA0464df166E1"
    override val REGISTRATION_SIMPLE_CONTRACT_ADRRESS = "0x497D6957729d3a39D43843BD27E6cbD12310F273"

    // STRIPPED (Task C5): see TestNetConfig - only consumer was PointsManager.kt.
    // FEEDBACK_EMAIL: Task C5's worktree branched before Task C4's rebrand fix landed on
    // main and still had Rarimo's own "info@rarilabs.com" - this merge keeps C4's real fix.
    override val FEEDBACK_EMAIL = "support@foundation-global.com"
    override val CHAIN = RarimoChains.Mainnet
    override val GOOGLE_WEB_KEY = Keys.GOOGLE_WEB_KEY
    override val APP_ID_FIREBASE = Keys.APP_ID
    // STRIPPED (Task C5, controller correction): RARIMO_EXPLORER's only consumer,
    // WalletTransactionCard.kt, is gone with the wallet module.
    // Production tier of the global FCM topic, matching iOS Task B1's Production.xcconfig
    // value exactly - both platforms subscribe to the same topic. (Task C5's worktree
    // branched before this Task C4 fix landed on main and still had the old "rarime" value
    // in its own copy - this merge keeps C4's real rebrand.)
    override val GLOBAL_NOTIFICATION_TOPIC = "foundation"
    // STRIPPED (Task C5, controller correction): REWARD_NOTIFICATION_TOPIC and
    // APPSFLYER_DEV_KEY are gone for the same reasons as TestNetConfig above.

    // STRIPPED (Task C5): Freedom Tool / Polls (VOTING_*/PROPOSAL/MULTICALL) and
    // digitalLikeness (FACE_REGISTRY_ADDRESS) deleted entirely.








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
