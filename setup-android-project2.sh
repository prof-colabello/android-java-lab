#!/bin/bash
# =============================================================
#  setup-android-project.sh
#  Configura un ambiente Android completo in GitHub Codespaces
#  Testato su: mcr.microsoft.com/devcontainers/universal:2
# =============================================================

set -e

# Colori per output leggibile
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
info() { echo -e "${YELLOW}[>>]${NC} $1"; }
err()  { echo -e "${RED}[ERR]${NC} $1"; exit 1; }

echo ""
echo "================================================="
echo "  Setup ambiente Android - Java 17 + SDK 33"
echo "================================================="
echo ""

# ---------------------------------------------------------
# 1. JAVA 17
# ---------------------------------------------------------
info "Verifica Java 17..."

JAVA17_PATH=""

# Cerca Java 17 nei path comuni dei devcontainer universal
for candidate in \
    /usr/lib/jvm/temurin-17 \
    /usr/lib/jvm/java-17-openjdk-amd64 \
    /usr/lib/jvm/java-17-openjdk \
    /usr/local/sdkman/candidates/java/17*/jre \
    /opt/java/17* ; do
    if [ -f "$candidate/bin/java" ]; then
        JAVA17_PATH="$candidate"
        break
    fi
done

# Se non trovato, installalo
if [ -z "$JAVA17_PATH" ]; then
    info "Java 17 non trovato. Installazione in corso..."
    sudo apt-get update -qq
    sudo apt-get install -y temurin-17-jdk 2>/dev/null || \
    sudo apt-get install -y openjdk-17-jdk 2>/dev/null || \
    err "Impossibile installare Java 17. Controlla la connessione."

    # Cerca di nuovo dopo l'installazione
    for candidate in \
        /usr/lib/jvm/temurin-17 \
        /usr/lib/jvm/java-17-openjdk-amd64 \
        /usr/lib/jvm/java-17-openjdk ; do
        if [ -f "$candidate/bin/java" ]; then
            JAVA17_PATH="$candidate"
            break
        fi
    done
fi

[ -z "$JAVA17_PATH" ] && err "Java 17 non trovato dopo l'installazione."

export JAVA_HOME="$JAVA17_PATH"
export PATH="$JAVA_HOME/bin:$PATH"

JAVA_VER=$("$JAVA_HOME/bin/java" -version 2>&1 | head -1)
ok "Java trovato: $JAVA_VER (path: $JAVA_HOME)"

# ---------------------------------------------------------
# 2. ANDROID SDK
# ---------------------------------------------------------
ANDROID_SDK_ROOT="$HOME/android-sdk"
CMDLINE_TOOLS="$ANDROID_SDK_ROOT/cmdline-tools/latest"

info "Verifica Android SDK..."

if [ ! -f "$CMDLINE_TOOLS/bin/sdkmanager" ]; then
    info "Android SDK non trovato. Installazione in corso..."

    mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"

    CMDTOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
    info "Download Android command-line tools..."
    wget -q --show-progress "$CMDTOOLS_URL" -O /tmp/cmdtools.zip || \
        err "Download Android SDK fallito. Controlla la connessione."

    unzip -q /tmp/cmdtools.zip -d /tmp/cmdtools_extracted
    mv /tmp/cmdtools_extracted/cmdline-tools "$CMDLINE_TOOLS"
    rm -rf /tmp/cmdtools.zip /tmp/cmdtools_extracted

    ok "Android command-line tools installati."
else
    ok "Android SDK già presente."
fi

export PATH="$CMDLINE_TOOLS/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"

# Aggiungi variabili al .bashrc per le sessioni future
grep -q "ANDROID_SDK_ROOT" ~/.bashrc || cat >> ~/.bashrc << BASHEOF

# Android SDK
export ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export JAVA_HOME="$JAVA_HOME"
export PATH="\$PATH:$CMDLINE_TOOLS/bin:$ANDROID_SDK_ROOT/platform-tools:\$JAVA_HOME/bin"
BASHEOF

# Installa componenti SDK necessari
info "Installazione Android SDK API 33 e build-tools..."
yes | "$CMDLINE_TOOLS/bin/sdkmanager" --sdk_root="$ANDROID_SDK_ROOT" --licenses > /dev/null 2>&1
"$CMDLINE_TOOLS/bin/sdkmanager" --sdk_root="$ANDROID_SDK_ROOT" \
    "platforms;android-33" \
    "build-tools;33.0.2" \
    "platform-tools" > /dev/null 2>&1

ok "Android SDK API 33 installato."

# ---------------------------------------------------------
# 3. GRADLE WRAPPER
# ---------------------------------------------------------
info "Configurazione Gradle wrapper..."

mkdir -p gradle/wrapper

# Scarica gradle-wrapper.jar dall'unico source ufficiale affidabile
WRAPPER_JAR_URL="https://raw.githubusercontent.com/gradle/gradle/v8.2.0/gradle/wrapper/gradle-wrapper.jar"
wget -q "$WRAPPER_JAR_URL" -O gradle/wrapper/gradle-wrapper.jar || \
    err "Download gradle-wrapper.jar fallito."

# Scarica lo script gradlew ufficiale
wget -q "https://raw.githubusercontent.com/gradle/gradle/v8.2.0/gradlew" -O gradlew
chmod +x gradlew

cat > gradle/wrapper/gradle-wrapper.properties << 'EOF'
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.2-bin.zip
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
EOF

ok "Gradle wrapper 8.2 configurato."

# ---------------------------------------------------------
# 4. FILE DI CONFIGURAZIONE GRADLE
# ---------------------------------------------------------
info "Creazione file di configurazione Gradle..."

# settings.gradle — include anche pluginManagement (best practice AGP 8.x)
cat > settings.gradle << 'EOF'
pluginManagement {
    repositories {
        google()
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

# build.gradle root — in AGP 8.x non si usa più allprojects per i repository
cat > build.gradle << 'EOF'
plugins {
    id 'com.android.application' version '8.1.0' apply false
}
EOF

# gradle.properties
cat > gradle.properties << EOF
android.useAndroidX=true
android.enableJetifier=true
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
org.gradle.java.home=${JAVA_HOME}
EOF

ok "File Gradle configurati."

# ---------------------------------------------------------
# 5. MODULO APP
# ---------------------------------------------------------
info "Creazione struttura modulo app..."

mkdir -p app/src/main/java/it/scuola/miaapp
mkdir -p app/src/main/res/layout
mkdir -p app/src/main/res/values
mkdir -p app/src/main/res/drawable

# app/build.gradle
cat > app/build.gradle << 'EOF'
plugins {
    id 'com.android.application'
}

android {
    namespace 'it.scuola.miaapp'
    compileSdk 33

    defaultConfig {
        applicationId "it.scuola.miaapp"
        minSdk 24
        targetSdk 33
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
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'com.google.android.material:material:1.9.0'
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
    <string name="app_name">MiaApp</string>
    <string name="button_text">Cliccami</string>
    <string name="hello">Ciao Mondo!</string>
</resources>
EOF

# themes.xml — necessario per il tema Material
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
        <item name="android:statusBarColor">?attr/colorPrimaryVariant</item>
    </style>
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

# activity_main.xml — layout con ConstraintLayout (standard Android)
cat > app/src/main/res/layout/activity_main.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<androidx.constraintlayout.widget.ConstraintLayout
    xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent"
    android:layout_height="match_parent">

    <TextView
        android:id="@+id/textView"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="@string/hello"
        android:textSize="28sp"
        android:textStyle="bold"
        app:layout_constraintBottom_toTopOf="@+id/button"
        app:layout_constraintEnd_toEndOf="parent"
        app:layout_constraintStart_toStartOf="parent"
        app:layout_constraintTop_toTopOf="parent"
        app:layout_constraintVertical_chainStyle="packed"/>

    <Button
        android:id="@+id/button"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_marginTop="32dp"
        android:text="@string/button_text"
        app:layout_constraintBottom_toBottomOf="parent"
        app:layout_constraintEnd_toEndOf="parent"
        app:layout_constraintStart_toStartOf="parent"
        app:layout_constraintTop_toBottomOf="@+id/textView"/>

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

    private TextView textView;
    private Button button;
    private int count = 0;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        textView = findViewById(R.id.textView);
        button   = findViewById(R.id.button);

        button.setOnClickListener(v -> {
            count++;
            textView.setText("Hai cliccato " + count + " volt" + (count == 1 ? "a" : "e") + "!");
        });
    }
}
EOF

# proguard-rules.pro (file vuoto richiesto da AGP)
touch app/proguard-rules.pro

ok "Struttura app creata."

# ---------------------------------------------------------
# 6. ICONE LAUNCHER (placeholder per evitare warning)
# ---------------------------------------------------------
info "Creazione icone launcher placeholder..."

for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
    mkdir -p "app/src/main/res/mipmap-${density}"
    # Crea un PNG minimo valido (1x1 pixel trasparente) come placeholder
    printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82' \
        > "app/src/main/res/mipmap-${density}/ic_launcher.png"
    cp "app/src/main/res/mipmap-${density}/ic_launcher.png" \
       "app/src/main/res/mipmap-${density}/ic_launcher_round.png"
done

ok "Icone placeholder create."

# ---------------------------------------------------------
# 7. .gitignore
# ---------------------------------------------------------
cat > .gitignore << 'EOF'
# Build
.gradle/
build/
app/build/
*.apk
*.aab

# SDK locale
local.properties

# IDE
.idea/
*.iml
.vscode/settings.json

# OS
.DS_Store
Thumbs.db
EOF

ok ".gitignore creato."

# ---------------------------------------------------------
# 8. README
# ---------------------------------------------------------
cat > README.md << 'EOF'
# Android Lab — Ambiente base

## Compilare il progetto

```bash
./gradlew assembleDebug
```

L'APK si trova in `app/build/outputs/apk/debug/app-debug.apk`.

## Struttura del progetto

```
app/src/main/
├── java/it/scuola/miaapp/
│   └── MainActivity.java       ← punto di partenza
├── res/
│   ├── layout/activity_main.xml
│   └── values/strings.xml
└── AndroidManifest.xml
```

## Installare l'APK sullo smartphone

1. Abilita **"Origini sconosciute"** nelle impostazioni del telefono
2. Scarica l'APK dal pannello file di VS Code (click destro → Download)
3. Trasferisci sul telefono e installa
EOF

# ---------------------------------------------------------
# 9. BUILD DI VERIFICA
# ---------------------------------------------------------
echo ""
echo "================================================="
info "Avvio build di verifica..."
echo "================================================="

# Esporta ANDROID_HOME per Gradle
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT"

./gradlew assembleDebug \
    -Dorg.gradle.java.home="$JAVA_HOME" \
    --no-daemon \
    --warning-mode none

echo ""
echo "================================================="
echo -e "${GREEN}  BUILD SUCCESSFUL!${NC}"
echo "  APK: app/build/outputs/apk/debug/app-debug.apk"
echo "================================================="
echo ""
echo "Per compilare in futuro:"
echo "  ./gradlew assembleDebug"
echo ""
