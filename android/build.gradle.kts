allprojects {
    repositories {
        google()
        mavenCentral()
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

// solana_mobile_client (0.1.2) ships its own Android library module hardcoded
// to compileSdkVersion 31, which is now too old for several AndroidX
// libraries it transitively depends on (lifecycle, tracing, etc. all require
// 33/34+). Force every *plugin* Android subproject to compile against the
// same SDK as :app so that stale hardcoded value doesn't break the build.
// Needs afterEvaluate (compileSdkVersion(36) has to run after the plugin's
// own build.gradle sets compileSdkVersion 31, not before) but :app itself is
// excluded: evaluationDependsOn(":app") above forces :app to fully evaluate
// early, and calling afterEvaluate on an already-evaluated project throws.
// :app doesn't need this anyway — its compileSdk already comes from
// flutter.compileSdkVersion. Safe to remove once solana_mobile_client bumps
// its own compileSdk.
subprojects {
    if (name != "app") {
        afterEvaluate {
            extensions.findByType<com.android.build.gradle.BaseExtension>()?.compileSdkVersion(36)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
