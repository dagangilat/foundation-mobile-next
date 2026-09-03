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
    override val RELAYER_URL = "https://api.orgs.app.stage.rarime.com"
    override val COSMOS_RPC_URL = "https://rpc-api.node1.mainnet-beta.rarimo.com"


    override val POINTS_SVC_ID = "0x77fabbc6cb41a11d4fb6918696b3550d5d602f252436dd587f9065b7c4e62b"

    override val ICAO_COSMOS_RPC = "core-api.node1.mainnet-beta.rarimo.com:443"
    override val MASTER_CERTIFICATES_FILENAME = "icaopkd-list.ldif"
    override val MASTER_CERTIFICATES_BUCKETNAME = "rarimo-temp"
    override val EVM_RPC_URL = "https://rpc.evm.mainnet.rarimo.com"
    override val REGISTER_CONTRACT_ADDRESS = "0x435E8833bC8c6F5Fdfc1cd7E45D5760b523f4020"
    override val REGISTRATION_SIMPLE_CONTRACT_ADRRESS = "0xd63782478CA40b587785700Ce49248775398b045"
    override val CERTIFICATES_SMT_CONTRACT_ADDRESS = "0xc2974679359c756bf97ff6B698377E02c083F3D4"
    override val REGISTRATION_SMT_CONTRACT_ADDRESS = "0xF19a85B10d705Ed3bAF3c0eCe3E73d8077Bf6481"
    override val STATE_KEEPER_CONTRACT_ADDRESS = "0x9EDADB216C1971cf0343b8C687cF76E7102584DB"

    override val FEEDBACK_EMAIL = "apereliez1@gmail.com"
    override val CHAIN = RarimoChains.MainnetBeta
    override val GOOGLE_WEB_KEY = Keys.GOOGLE_WEB_KEY
    override val APP_ID_FIREBASE = Keys.APP_ID


    override val GLOBAL_NOTIFICATION_TOPIC = "rarime-stage"





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
    override val RELAYER_URL = "https://api.app.rarime.com"
    override val EVM_RPC_URL = "https://l2.rarimo.com"
    override val COSMOS_RPC_URL = "https://rpc-api.mainnet.rarimo.com"


    override val POINTS_SVC_ID = "0x77fabbc6cb41a11d4fb6918696b3550d5d602f252436dd587f9065b7c4e62b"

    override val ICAO_COSMOS_RPC = "core-api.mainnet.rarimo.com:443"
    override val MASTER_CERTIFICATES_FILENAME = "icaopkd-list.ldif"
    override val MASTER_CERTIFICATES_BUCKETNAME = "rarimo-temp"

    override val REGISTER_CONTRACT_ADDRESS = "0x11BB4B14AA6e4b836580F3DBBa741dD89423B971"
    override val CERTIFICATES_SMT_CONTRACT_ADDRESS = "0xA8b350d699632569D5351B20ffC1b31202AcEDD8"
    override val REGISTRATION_SMT_CONTRACT_ADDRESS = "0x479F84502Db545FA8d2275372E0582425204A879"
    override val STATE_KEEPER_CONTRACT_ADDRESS = "0x61aa5b68D811884dA4FEC2De4a7AA0464df166E1"
    override val REGISTRATION_SIMPLE_CONTRACT_ADRRESS = "0x497D6957729d3a39D43843BD27E6cbD12310F273"

    override val FEEDBACK_EMAIL = "info@rarilabs.com"
    override val CHAIN = RarimoChains.Mainnet
    override val GOOGLE_WEB_KEY = Keys.GOOGLE_WEB_KEY
    override val APP_ID_FIREBASE = Keys.APP_ID
    override val GLOBAL_NOTIFICATION_TOPIC = "rarime"








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
