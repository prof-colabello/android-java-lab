#!/bin/bash
# =============================================================
#  setup-android-project.sh
#  Configura un progetto Android completo in GitHub Codespaces
#
#  Ambiente target: mcr.microsoft.com/devcontainers/universal:2
#  Java disponibile: 21.x via SDKMAN (/usr/local/sdkman/candidates/java/)
#  Gradle disponibile: 9.4.1 preinstallato via SDKMAN
#  Android SDK: non preinstallato, scaricato da questo script
#
#  Versioni usate:
#    - Java:         21 (presente nel container)
#    - Gradle:       8.7 (wrapper — AGP 8.3 richiede min 8.6)
#    - AGP:          8.3.2 (stabile, compatibile Java 21 + Gradle 8.6+)
#    - Android SDK:  API 34 (Android 14 — target corrente)
#    - Build-tools:  34.0.0
# =============================================================

set -e

# Colori
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[OK]${NC}  $1"; }
info() { echo -e "${YELLOW}[..]${NC}  $1"; }
err()  { echo -e "${RED}[ERR]${NC} $1"; exit 1; }
line() { echo "---------------------------------------------"; }

echo ""
echo "============================================="
echo "  Setup Android Lab — Java 21 + SDK 34"
echo "============================================="
echo ""

# ---------------------------------------------------------
# 1. INDIVIDUA JAVA 21 (preinstallato via SDKMAN)
# ---------------------------------------------------------
info "Ricerca Java 21..."

JAVA_HOME=""

# SDKMAN nel devcontainer universal
SDKMAN_JAVA="/usr/local/sdkman/candidates/java"
if [ -d "$SDKMAN_JAVA" ]; then
    # Cerca una versione 21.x
    JAVA21=$(find "$SDKMAN_JAVA" -maxdepth 1 -name "21*" -type d | sort | tail -1)
    if [ -n "$JAVA21" ] && [ -f "$JAVA21/bin/java" ]; then
        JAVA_HOME="$JAVA21"
    fi
fi

# Fallback: cerca nei path standard
if [ -z "$JAVA_HOME" ]; then
    for candidate in \
        /usr/lib/jvm/java-21-openjdk-amd64 \
        /usr/lib/jvm/java-21-openjdk \
        /usr/lib/jvm/temurin-21 \
        /usr/local/lib/jvm/java-21; do
        if [ -f "$candidate/bin/java" ]; then
            JAVA_HOME="$candidate"
            break
        fi
    done
fi

# Ultimo fallback: usa java corrente se è 21+
if [ -z "$JAVA_HOME" ]; then
    CURRENT_JAVA=$(java -version 2>&1 | head -1 | grep -oP '(?<=version ")\d+' || echo "0")
    if [ "$CURRENT_JAVA" -ge 17 ] 2>/dev/null; then
        JAVA_HOME=$(java -XshowSettings:all -version 2>&1 | grep "java.home" | awk '{print $3}')
        # Risali alla JDK root se punta alla JRE
        [ -f "$JAVA_HOME/../bin/javac" ] && JAVA_HOME="$JAVA_HOME/.."
    fi
fi

[ -z "$JAVA_HOME" ] && err "Java 17+ non trovato. Verifica che il devcontainer sia 'universal:2'."

export JAVA_HOME=$(realpath "$JAVA_HOME")
export PATH="$JAVA_HOME/bin:$PATH"
JAVA_VERSION=$("$JAVA_HOME/bin/java" -version 2>&1 | head -1)
ok "Java: $JAVA_VERSION"
ok "JAVA_HOME: $JAVA_HOME"

# ---------------------------------------------------------
# 2. ANDROID SDK
# ---------------------------------------------------------
line
info "Installazione Android SDK..."

ANDROID_SDK_ROOT="$HOME/android-sdk"
CMDLINE_TOOLS="$ANDROID_SDK_ROOT/cmdline-tools/latest"

if [ -f "$CMDLINE_TOOLS/bin/sdkmanager" ]; then
    ok "Android SDK già presente, skip download."
else
    info "Download Android command-line tools..."
    mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"

    TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
    wget -q --show-progress "$TOOLS_URL" -O /tmp/cmdtools.zip \
        || err "Download fallito. Verifica la connessione internet del Codespace."

    info "Estrazione..."
    unzip -q /tmp/cmdtools.zip -d /tmp/cmdtools_tmp
    mv /tmp/cmdtools_tmp/cmdline-tools "$CMDLINE_TOOLS"
    rm -rf /tmp/cmdtools.zip /tmp/cmdtools_tmp
    ok "Command-line tools installati."
fi

export ANDROID_SDK_ROOT
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export PATH="$CMDLINE_TOOLS/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"

info "Installazione SDK API 34 + build-tools 34.0.0..."
yes | "$CMDLINE_TOOLS/bin/sdkmanager" \
    --sdk_root="$ANDROID_SDK_ROOT" \
    --licenses > /dev/null 2>&1 || true

"$CMDLINE_TOOLS/bin/sdkmanager" \
    --sdk_root="$ANDROID_SDK_ROOT" \
    "platforms;android-34" \
    "build-tools;34.0.0" \
    "platform-tools" 2>&1 | grep -v "^\[=" || true

ok "Android SDK API 34 installato."

# Scrivi le variabili nel .bashrc per le sessioni future
if ! grep -q "ANDROID_SDK_ROOT" ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << BASHEOF

# === Android SDK ===
export ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export JAVA_HOME="$JAVA_HOME"
export PATH="\$PATH:$CMDLINE_TOOLS/bin:$ANDROID_SDK_ROOT/platform-tools:\$JAVA_HOME/bin"
BASHEOF
    ok "Variabili ambiente aggiunte a ~/.bashrc"
fi

# ---------------------------------------------------------
# 3. GRADLE WRAPPER
#    AGP 8.3.2 richiede Gradle >= 8.6
#    Usiamo 8.7 — stabile e testato con AGP 8.3.x
# ---------------------------------------------------------
line
info "Configurazione Gradle wrapper 8.7..."

mkdir -p gradle/wrapper

# gradle-wrapper.jar: scaricato dal repository ufficiale Gradle su GitHub
WRAPPER_JAR_URL="https://raw.githubusercontent.com/gradle/gradle/v8.7.0/gradle/wrapper/gradle-wrapper.jar"
wget -q "$WRAPPER_JAR_URL" -O gradle/wrapper/gradle-wrapper.jar \
    || err "Download gradle-wrapper.jar fallito."

GRADLEW_URL="https://raw.githubusercontent.com/gradle/gradle/v8.7.0/gradlew"
wget -q "$GRADLEW_URL" -O gradlew \
    || err "Download gradlew fallito."
chmod +x gradlew

cat > gradle/wrapper/gradle-wrapper.properties << 'EOF'
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.7-bin.zip
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
EOF

ok "Gradle wrapper 8.7 configurato."

# ---------------------------------------------------------
# 4. FILE DI CONFIGURAZIONE GRADLE
# ---------------------------------------------------------
line
info "Creazione file configurazione Gradle..."

# settings.gradle — stile moderno AGP 8.x
cat > settings.gradle << 'EOF'
pluginManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "AndroidLab"
include ':app'
EOF

# build.gradle root — solo dichiarazione plugin, niente allprojects
cat > build.gradle << 'EOF'
plugins {
    id 'com.android.application' version '8.3.2' apply false
}
EOF

# gradle.properties — includiamo JAVA_HOME dinamico
cat > gradle.properties << EOF
# AndroidX
android.useAndroidX=true
android.enableJetifier=true

# Memoria JVM per Gradle daemon
org.gradle.jvmargs=-Xmx2048m -XX:MaxMetaspaceSize=512m -Dfile.encoding=UTF-8

# Java home — punta a Java 21 trovato sopra
org.gradle.java.home=${JAVA_HOME}

# Opzionale: abilita build parallele
org.gradle.parallel=true
EOF

ok "File Gradle configurati."

# ---------------------------------------------------------
# 5. MODULO APP
# ---------------------------------------------------------
line
info "Creazione struttura modulo app..."

mkdir -p app/src/main/java/it/scuola/miaapp
mkdir -p app/src/main/res/layout
mkdir -p app/src/main/res/values
mkdir -p app/src/main/res/mipmap-mdpi
mkdir -p app/src/main/res/mipmap-hdpi
mkdir -p app/src/main/res/mipmap-xhdpi
mkdir -p app/src/main/res/mipmap-xxhdpi
mkdir -p app/src/main/res/mipmap-xxxhdpi

# app/build.gradle
# compileOptions: VERSION_11 è compatibile con qualsiasi JDK 11+
# (non VERSION_17/21 che causerebbe problemi con JDK < 17)
cat > app/build.gradle << 'EOF'
plugins {
    id 'com.android.application'
}

android {
    namespace 'it.scuola.miaapp'
    compileSdk 34

    defaultConfig {
        applicationId "it.scuola.miaapp"
        minSdk 24
        targetSdk 34
        versionCode 1
        versionName "1.0"
    }

    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_11
        targetCompatibility JavaVersion.VERSION_11
    }
}

dependencies {
    implementation 'androidx.appcompat:appcompat:1.7.0'
    implementation 'com.google.android.material:material:1.12.0'
    implementation 'androidx.constraintlayout:constraintlayout:2.1.4'
}
EOF

# AndroidManifest.xml
cat > app/src/main/AndroidManifest.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:supportsRtl="true"
        android:theme="@style/Theme.MiaApp">
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

# strings.xml
cat > app/src/main/res/values/strings.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">AndroidLab</string>
</resources>
EOF

# colors.xml
cat > app/src/main/res/values/colors.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="purple_200">#FFBB86FC</color>
    <color name="purple_500">#FF6200EE</color>
    <color name="purple_700">#FF3700B3</color>
    <color name="teal_200">#FF03DAC5</color>
    <color name="teal_700">#FF018786</color>
    <color name="black">#FF000000</color>
    <color name="white">#FFFFFFFF</color>
</resources>
EOF

# themes.xml — usa Material Components (richiesto da material:1.12.0)
cat > app/src/main/res/values/themes.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="Theme.MiaApp" parent="Theme.MaterialComponents.DayNight.DarkActionBar">
        <item name="colorPrimary">@color/purple_500</item>
        <item name="colorPrimaryVariant">@color/purple_700</item>
        <item name="colorOnPrimary">@color/white</item>
        <item name="colorSecondary">@color/teal_200</item>
        <item name="colorSecondaryVariant">@color/teal_700</item>
        <item name="colorOnSecondary">@color/black</item>
        <item name="android:statusBarColor" tools:targetApi="l">?attr/colorPrimaryVariant</item>
    </style>
</resources>
EOF

# activity_main.xml — ConstraintLayout (standard Android moderno)
cat > app/src/main/res/layout/activity_main.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<androidx.constraintlayout.widget.ConstraintLayout
    xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent"
    android:layout_height="match_parent">

    <TextView
        android:id="@+id/tvMessaggio"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="Ciao Mondo!"
        android:textSize="28sp"
        android:textStyle="bold"
        app:layout_constraintBottom_toTopOf="@+id/btnClicca"
        app:layout_constraintEnd_toEndOf="parent"
        app:layout_constraintStart_toStartOf="parent"
        app:layout_constraintTop_toTopOf="parent"
        app:layout_constraintVertical_chainStyle="packed"/>

    <Button
        android:id="@+id/btnClicca"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_marginTop="32dp"
        android:text="Cliccami"
        app:layout_constraintBottom_toBottomOf="parent"
        app:layout_constraintEnd_toEndOf="parent"
        app:layout_constraintStart_toStartOf="parent"
        app:layout_constraintTop_toBottomOf="@+id/tvMessaggio"/>

</androidx.constraintlayout.widget.ConstraintLayout>
EOF

# MainActivity.java
cat > app/src/main/java/it/scuola/miaapp/MainActivity.java << 'EOF'
package it.scuola.miaapp;

import android.os.Bundle;
import android.widget.Button;
import android.widget.TextView;
import androidx.appcompat.app.AppCompatActivity;

public class MainActivity extends AppCompatActivity {

    private TextView tvMessaggio;
    private Button btnClicca;
    private int contatore = 0;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        tvMessaggio = findViewById(R.id.tvMessaggio);
        btnClicca   = findViewById(R.id.btnClicca);

        btnClicca.setOnClickListener(v -> {
            contatore++;
            tvMessaggio.setText("Hai cliccato " + contatore
                + (contatore == 1 ? " volta!" : " volte!"));
        });
    }
}
EOF

# proguard-rules.pro (richiesto da AGP anche se vuoto)
touch app/proguard-rules.pro

ok "Codice sorgente creato."

# ---------------------------------------------------------
# 6. ICONE LAUNCHER
#    PNG 1x1 pixel valido come placeholder
#    Gli studenti potranno sostituirle in seguito
# ---------------------------------------------------------
info "Creazione icone launcher placeholder..."
PNG_1X1='\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82'

for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
    printf "$PNG_1X1" > "app/src/main/res/mipmap-${density}/ic_launcher.png"
    cp "app/src/main/res/mipmap-${density}/ic_launcher.png" \
       "app/src/main/res/mipmap-${density}/ic_launcher_round.png"
done
ok "Icone placeholder create."

# ---------------------------------------------------------
# 7. .gitignore
# ---------------------------------------------------------
cat > .gitignore << 'EOF'
# File generati dalla build — non caricare su GitHub
.gradle/
build/
app/build/
*.apk
*.aab
*.ap_

# Configurazione locale — ogni sviluppatore ha la sua
local.properties

# IDE
.idea/
*.iml
*.iws
*.ipr
.vscode/settings.json

# Android SDK locale (scaricato dallo script)
android-sdk/

# OS
.DS_Store
Thumbs.db
EOF

# ---------------------------------------------------------
# 8. README
# ---------------------------------------------------------
cat > README.md << 'EOF'
# Android Lab

Progetto Android base per esercitazioni scolastiche.

## Primo avvio

Se l'ambiente non è ancora configurato, lancia:

```bash
chmod +x setup-android-project.sh
./setup-android-project.sh
```

## Compilare il progetto

```bash
./gradlew assembleDebug
```

L'APK si trova in:
```
app/build/outputs/apk/debug/app-debug.apk
```

## Installare su smartphone

1. Abilita **"Origini sconosciute"** nelle impostazioni del telefono
2. Click destro su `app-debug.apk` nel pannello file di VS Code → **Download**
3. Trasferisci l'APK sullo smartphone e installa

## Struttura del progetto

```
app/src/main/
├── java/it/scuola/miaapp/
│   └── MainActivity.java        ← modifica qui
├── res/
│   ├── layout/activity_main.xml ← layout UI
│   └── values/strings.xml       ← testi
└── AndroidManifest.xml
```
EOF

# ---------------------------------------------------------
# 9. BUILD DI VERIFICA FINALE
# ---------------------------------------------------------
line
echo ""
info "Avvio build di verifica..."
echo ""

./gradlew assembleDebug \
    -Dorg.gradle.java.home="$JAVA_HOME" \
    -Pandroid.sdk.dir="$ANDROID_SDK_ROOT" \
    --no-daemon \
    --warning-mode none \
    --console plain

echo ""
echo "============================================="
echo -e "${GREEN}  BUILD SUCCESSFUL!${NC}"
echo "  APK → app/build/outputs/apk/debug/app-debug.apk"
echo "============================================="
echo ""
echo "Prossimi passi:"
echo "  1. git add ."
echo "  2. git commit -m 'Ambiente Android pronto'"
echo "  3. git push"
echo ""
