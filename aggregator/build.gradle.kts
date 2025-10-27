plugins {
    application
    kotlin("jvm") version "2.2.21"
    kotlin("plugin.serialization") version "2.2.21"
}

kotlin {
    jvmToolchain(17)
}

application {
    mainClass.set("app.aggregator.MainKt")
}

dependencies {
    implementation(project(":common"))
    implementation("io.ktor:ktor-server-core-jvm:3.3.1")
    implementation("io.ktor:ktor-server-netty-jvm:3.3.1")
    implementation("io.ktor:ktor-server-content-negotiation-jvm:3.3.1")
    implementation("io.ktor:ktor-serialization-kotlinx-json-jvm:3.3.1")
    implementation("io.ktor:ktor-client-core-jvm:3.3.1")
    implementation("io.ktor:ktor-client-cio-jvm:3.3.1")
    implementation("io.ktor:ktor-client-content-negotiation-jvm:3.3.1")
    implementation("ch.qos.logback:logback-classic:1.5.19")
    testImplementation(kotlin("test"))
}

tasks.test { useJUnitPlatform() }
