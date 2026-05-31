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
    project.evaluationDependsOn(":app")
}

fun forceAndroidSdk(project: Project) {
    val androidExt = project.extensions.findByName("android") ?: return
    val methods = androidExt.javaClass.methods.filter { it.parameterCount == 1 }

    fun invokeSetter(name: String, intValue: Int, stringValue: String) {
        val candidates = methods.filter { it.name == name }
        for (method in candidates) {
            val parameterType = method.parameterTypes.firstOrNull() ?: continue
            runCatching {
                when (parameterType) {
                    Int::class.javaPrimitiveType,
                    java.lang.Integer::class.java -> method.invoke(androidExt, intValue)
                    String::class.java -> method.invoke(androidExt, stringValue)
                    else -> {
                        runCatching { method.invoke(androidExt, intValue) }
                            .getOrElse { method.invoke(androidExt, stringValue) }
                    }
                }
            }.getOrNull()?.let { return }
        }
    }

    invokeSetter("setCompileSdk", 36, "android-36")
    invokeSetter("setCompileSdkVersion", 36, "android-36")
    invokeSetter("setTargetSdk", 36, "36")
    invokeSetter("setTargetSdkVersion", 36, "36")
}

subprojects {
    val applyFix: Project.() -> Unit = {
        if (plugins.hasPlugin("com.android.library") || plugins.hasPlugin("com.android.application")) {
            forceAndroidSdk(this)
        }
    }

    if (state.executed) {
        applyFix(this)
    } else {
        afterEvaluate { applyFix(this) }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
