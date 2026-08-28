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
// Manche Flutter-Plugins kompilieren gegen ein zu niedriges compileSdk
// (z.B. vosk_flutter_service -> android-33), was mit neueren AndroidX-
// Abhängigkeiten (exifinterface) bricht. Deshalb heben wir das compileSdk
// aller Android-Subprojekte auf 36 an – reflektiv, ohne AGP-Typ-Import.
// Muss VOR dem evaluationDependsOn-Block registriert werden ("app" ist
// bereits auf 36 und wird durch evaluationDependsOn früh evaluiert).
subprojects {
    if (project.name != "app") {
        afterEvaluate {
            val android = project.extensions.findByName("android")
            if (android != null) {
                runCatching {
                    val method = android.javaClass.methods.firstOrNull {
                        it.name == "compileSdkVersion" &&
                            it.parameterTypes.size == 1 &&
                            it.parameterTypes[0] == Int::class.javaPrimitiveType
                    }
                    method?.invoke(android, 36)
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
