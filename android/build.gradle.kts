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
}

tasks.register<Delete>("clean") {
    delete(rootBuildDir)
}
