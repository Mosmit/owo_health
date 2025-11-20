# Owolabi Health App (OwoHealth)

**Owolabi Health** is a Flutter-based personal health companion application designed to empower users to take control of their physical and mental well-being. The app integrates seamless tracking for vitals, moods, and medications with an intelligent symptom checker, all backed by a robust Firebase backend.
**Live display** Download apk ... https://github.com/Mosmit/owo_health/releases/download/v1.1.0/app-release.apk

## 📱 Features

### 1. 🏠 Smart Dashboard
* **Personalized Greetings:** Welcomes users based on the time of day.
* **Quick Actions:** One-tap access to Symptom Checks and Emergency protocols.
* **Daily Overview:** Real-time summary of logs recorded for the current day.

### 2. 🩺 Symptom Checker
* **Interactive Assessment:** Select common symptoms or describe specific issues.
* **Urgency Classification:** Users can tag symptoms as Low, Moderate, or Emergency.
* **Instant Recommendations:** Provides immediate advice based on the urgency level (e.g., "Seek immediate medical attention" vs "Rest and hydrate").

### 3. 🧠 Mood Tracker
* **Visual Logging:** Emoji-based interface for quick mood entry (Awful to Great).
* **Detailed Insights:** Option to add specific feelings (e.g., Anxious, Excited) and custom notes.
* **History:** Scrollable list of past emotional states.

### 4. 💓 Vitals Monitor
* **Comprehensive Logging:** Track Blood Pressure (Sys/Dia), Heart Rate (BPM), and Weight.
* **Data Visualization:** Interactive line charts powered by `fl_chart` to visualize Heart Rate trends over the last 7 entries.

### 5. 💊 Medicine Manager
* **Scheduler:** Add medications with specific dosage times.
* **Tracker:** Checkbox interface to mark medicines as taken for the day.

### 6. 📊 History & Analytics
* **Data Visualization:** Pie charts showing the distribution of symptom urgencies.
* **Trend Analysis:** Toggle between Line and Bar charts to view check-in frequency over time.
* **Record Management:** View detailed past reports and delete erroneous entries.

## 🛠 Tech Stack

* **Frontend:** [Flutter](https://flutter.dev/) (Dart)
* **Backend:** [Firebase](https://firebase.google.com/)
    * **Authentication:** Email & Password Sign-in.
    * **Cloud Firestore:** Real-time database for storing user logs, medicines, and health data.
* **State Management:** `StatefulWidget` & `StreamBuilder` for real-time data updates.
* **Key Packages:**
    * `fl_chart`: For statistical graphs.
    * `intl`: For date and time formatting.
    * `firebase_core` & `cloud_firestore`: For backend integration.

## 🎨 Design Notes

The app follows a clean, medical-grade aesthetic using a custom color palette:
* **Primary:** Teal/Green (`AppColors.primary`) representing health and growth.
* **Accent:** Soft Purple/Blue for secondary actions.
* **Urgency Colors:**
    * 🔴 **Emergency:** Red
    * 🟠 **Moderate:** Orange
    * 🟢 **Low:** Green
* **Typography:** Modern, legible fonts utilizing a hierarchy of Headings (H1-H3) and Body text.

## 🚀 Getting Started

Follow these steps to run the project locally.

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
* An IDE (VS Code or Android Studio).
* A Firebase project created.

### Installation

1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/Mosmit/owo_health.git](https://github.com/Mosmit/owo_health.git)
    cd owo_health
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Firebase Configuration:**
    * Ensure you have the [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/) installed.
    * Run the configuration command to link your Firebase project:
    ```bash
    flutterfire configure
    ```
    * *Note: This will update `lib/firebase_options.dart` with your specific API keys.*

4.  **Run the App:**
    * **Android/iOS:** Connect a device or start an emulator.
    * **Web:** Chrome/Edge.
    ```bash
    flutter run
    ```

