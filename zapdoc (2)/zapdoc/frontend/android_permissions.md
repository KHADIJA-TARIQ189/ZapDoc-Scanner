# Android setup

After running `flutter create .` inside `frontend/` to generate the native
Android/iOS projects (see main README), add these permissions.

## android/app/src/main/AndroidManifest.xml

Add inside the `<manifest>` tag, above `<application>`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-feature android:name="android.hardware.camera" android:required="false" />
<uses-feature android:name="android.hardware.camera.autofocus" android:required="false" />
```

If you're running the backend on plain HTTP on your LAN (not HTTPS) while
testing, also add `android:usesCleartextTraffic="true"` to the
`<application>` tag, e.g.:

```xml
<application
    android:label="zapdoc"
    android:usesCleartextTraffic="true"
    ...>
```

## ios/Runner/Info.plist

Add:

```xml
<key>NSCameraUsageDescription</key>
<string>ZapDoc needs camera access to scan documents.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>ZapDoc needs photo library access to import and save documents.</string>
```
