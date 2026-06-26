allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val rootBuildDir = file("${project.rootDir}/../build")
allprojects {
    buildDir = file("${rootBuildDir}/${project.name}")
}

subprojects {
    project.evaluationDependsOn(":app")
    tasks.withType<org.gradle.api.tasks.compile.JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_11.toString()
        targetCompatibility = JavaVersion.VERSION_11.toString()
    }
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        kotlinOptions.jvmTarget = JavaVersion.VERSION_11.toString()
    }
}

tasks.register<Delete>("clean") {
    delete(rootBuildDir)
}
