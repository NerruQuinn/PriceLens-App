allprojects {
    repositories {
        google()
        mavenCentral()
    }

    configurations.all {
        resolutionStrategy {
            force("com.android.tools.build:gradle:8.0.0")
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

allprojects {
    plugins.withId("com.android.application") {
        extensions.findByType<com.android.build.gradle.AppExtension>()?.ndkVersion = "28.2.13676358"
    }
    plugins.withId("com.android.library") {
        extensions.findByType<com.android.build.gradle.LibraryExtension>()?.ndkVersion = "28.2.13676358"
    }
}
