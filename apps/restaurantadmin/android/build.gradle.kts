buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Check for the latest version of the google-services plugin
        classpath("com.google.gms:google-services:4.4.2") // Example, verify latest
        // Check for the latest version of the App Distribution plugin
        classpath("com.google.firebase:firebase-appdistribution-gradle:4.2.0") // Example, verify latest
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
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
