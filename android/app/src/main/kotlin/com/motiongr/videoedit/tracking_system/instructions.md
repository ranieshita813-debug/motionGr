# Android নেটিভ ট্র্যাকিং (Kotlin + OpenCV) + Flutter

## ১. Gradle (android/app/build.gradle)
```gradle
android {
    defaultConfig {
        minSdk = 27            // getScaledFrameAtTime এর জন্য
    }
}
dependencies {
    implementation 'org.opencv:opencv:4.10.0'
}
```
APK ছোট রাখতে `flutter build apk --split-per-abi` ব্যবহার করুন।

## ২. ফাইল বসান
- `android/.../*.kt` তিনটি আপনার প্যাকেজ ফোল্ডারে রাখুন এবং প্রতিটি ফাইলের
  `package com.example.trackingapp` লাইন আপনার প্যাকেজ নাম দিয়ে বদলান।
  (আগে থেকে MainActivity থাকলে শুধু `configureFlutterEngine` এর অংশটুকু মিলিয়ে নিন।)
- `flutter/lib/tracking/*.dart` আপনার `lib/` এ কপি করুন।

## ৩. NanoTrack মডেল 
OpenCV Zoo এর `object_tracking_nanotrack` থেকে দুটি ফাইল নামিয়ে
`android/app/src/main/assets/` এ রাখুন:
- `nanotrack_backbone_sim.onnx`
- `nanotrack_head_sim.onnx`

না রাখলে নিজে থেকেই MIL ট্র্যাকারে ফিরে যায় (মান কিছুটা কম)।
ফলাফলের `result.tracker` দেখে বুঝবেন কোনটি ব্যবহার হয়েছে।

## ৪. ব্যবহার
```dart
final tracker = NativeTracker();
tracker.progress.listen((p) => setState(() => _progress = p));

final result = await tracker.track(
  videoPath: file.path,
  bbox: const Rect.fromLTWH(0.40, 0.30, 0.20, 0.30), // ইউজারের আঁকা বক্স, 0..1
);
setState(() => _points = result.points);

// প্লেয়ারের উপর
Stack(children: [
  VideoPlayer(controller),
  TrackedText(
    points: _points,
    positionSeconds: controller.value.position.inMilliseconds / 1000,
    videoSize: videoSize,
    text: 'আমার লেখা',
  ),
]);
```
প্লেয়ারের position বদলালে `setState` (বা ValueListenableBuilder) দিয়ে রিবিল্ড করুন।