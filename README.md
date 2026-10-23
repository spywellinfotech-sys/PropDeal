# Property Network – APK banane ka tarika

Ye app 9 cities (Saharanpur, Karnal, Yamunanagar, Dehradun, Haridwar, Roorkee, Rishikesh,
Panipat, Ambala) ke 115 property dealers aur builders ki list dikhata hai. Har contact ke
saath seedha **Call** aur **WhatsApp** button hai, Hindi/Hinglish dono me.

## Zaroorat
- Flutter SDK (3.22 ya naya) aur Android SDK (Android Studio ke saath aata hai)

## Steps (computer pe, terminal me)

```bash
# 1. Flutter ka khaali project banao
flutter create --org com.spywell --platforms android property_network_app

# 2. Is zip ki ye files us project me copy karke purani files replace karo:
#    pubspec.yaml
#    lib/main.dart
#    assets/index.html
#    android/app/src/main/AndroidManifest.xml

# 3. Packages lao aur APK banao
cd property_network_app
flutter pub get
flutter build apk --release
```

APK yahan milegi:
`build/app/outputs/flutter-apk/app-release.apk`

Ise phone me bhejo (WhatsApp, Drive ya USB se) aur install karo. Phone "unknown apps"
ki permission maange to de dena.

## Data badalna ho to
Saara data aur design `assets/index.html` me hai. Nayi list chahiye to bas ye file
badlo aur `flutter build apk --release` dobara chalao.

## Dhyan rahe
- Status (Call kiya, Interested…) aur WhatsApp message isi phone me save rehte hain.
- `flutter build apk --release` debug key se sign hoti hai. Ye apne phone pe ya
  doston ko dene ke liye theek hai. Play Store pe daalna ho to apni release key se sign
  karna padega.
