# QGroundControl Ground Control Station

[![Releases](https://img.shields.io/github/release/mavlink/QGroundControl.svg)](https://github.com/mavlink/QGroundControl/releases)

*QGroundControl* (QGC) is an intuitive and powerful ground control station (GCS) for UAVs.

The primary goal of QGC is ease of use for both first time and professional users.
It provides full flight control and mission planning for any MAVLink enabled drone, and vehicle setup for both PX4 and ArduPilot powered UAVs. Instructions for *using QGroundControl* are provided in the [User Manual](https://docs.qgroundcontrol.com/en/) (you may not need them because the UI is very intuitive!)

All the code is open-source, so you can contribute and evolve it as you want.
The [Developer Guide](https://dev.qgroundcontrol.com/en/) explains how to [build](https://dev.qgroundcontrol.com/en/getting_started/) and extend QGC.


Key Links:
* [Website](http://qgroundcontrol.com) (qgroundcontrol.com)
* [User Manual](https://docs.qgroundcontrol.com/en/)
* [Developer Guide](https://dev.qgroundcontrol.com/en/)
* [Discussion/Support](https://docs.qgroundcontrol.com/en/Support/Support.html)
* [Contributing](https://dev.qgroundcontrol.com/en/contribute/)
* [License](https://github.com/mavlink/qgroundcontrol/blob/master/COPYING.md)

Android apk build with command prompt (cmd):

Initial setups for build:

Jdk install

https://jdk.java.net/java-se-ri/11-MR2

![image](https://github.com/user-attachments/assets/1fc465f9-ab9c-4ff5-a98d-ad0cbc02bd50)


In Android Studio: SDK Manager sdk and ndk installation

Customize -> Configure -> Languages & Frameworks -> Android SDK

- SDK: Android 9.0 Pie
- NDK: 21.3.6528147 and 25.1.8937393

additional package: Android SDK Command line Tools

![image](https://github.com/user-attachments/assets/14a41daf-a2a1-451f-bbca-e0a6acd4d560)

![image](https://github.com/user-attachments/assets/ea5dfc27-cca7-4183-bbec-fe7da70c5dd9)

Setups in environment variables:

JAVA_HOME
- D:\Programs\Java\jdk-11.0.0.1

ANDROID_NDK_ROOT
- D:\Programs\Android\SDK\ndk\21.3.6528147

ANDROID_SDK_ROOT
- D:\Programs\Android\SDK

PATH:
- D:\Programs\Java\jdk-11.0.0.1\bin
- D:\Programs\Qt\5.15.2\android\bin
- D:\Programs\Qt\Tools\QtCreator\bin\jom


1. In QgroundControl folder, create build folder
2. Inside build folder, open cmd

Codes to build
   
    qmake.exe ../qgroundcontrol.pro -spec android-clang "CONFIG+=debug" "CONFIG+=qml_debug" ANDROID_ABIS="arm64-v8a"

    D:\Programs\Android\SDK\ndk\21.3.6528147\prebuilt\windows-x86_64\bin\make.exe -j8
    D:\Programs\Android\SDK\ndk\21.3.6528147\prebuilt\windows-x86_64\bin\make.exe apk


QTCreator to build

environment variables is same as Codes build environment.

- Android
Edit -> Preferences

![image](https://github.com/user-attachments/assets/bfc7984c-7996-4458-b533-9316d0bf7420)

Devices -> Android

![image](https://github.com/user-attachments/assets/9f6b8d0a-2112-4db6-806c-b24a0dafaa3f)

- Window

Edit -> Preferences -> Kits -> Compilers

![image](https://github.com/user-attachments/assets/1eb0f695-5290-449e-ad70-80dcb3aeddc1)

![image](https://github.com/user-attachments/assets/dbbad4d0-734f-410e-bb57-70ded306728f)


