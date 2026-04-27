# 현장 점검표 앱 (Field Inspection Checklist)

Flutter 기반 iOS/Android 현장점검 앱

---

## 주요 기능

- ✅ **2단계 점검표** (대분류 > 소항목)
- 📷 **항목별 사진 첨부** (카메라 / 갤러리)
- 🔘 **Y / N / NA + 특이사항** 입력
- 📋 **점검 이력 관리** (날짜 + 장소 필터)
- 📄 **PDF / Excel 내보내기 + 공유**
- ✏️ **점검표 편집** (분류 추가/삭제/순서 변경, 항목 추가/삭제)
- 💾 **로컬 저장** (앱 삭제 전까지 데이터 보존)

---

## 프로젝트 시작 방법

### 1. Flutter 프로젝트 생성

```bash
flutter create field_inspection --org com.yourcompany
cd field_inspection
```

### 2. 파일 덮어쓰기

제공된 파일들을 아래 위치에 복사:
```
lib/
  main.dart
  utils/theme.dart
  models/checklist_template.dart
  models/inspection.dart
  services/database_service.dart
  services/export_service.dart
  providers/template_provider.dart
  providers/inspection_provider.dart
  screens/home_screen.dart
  screens/inspection_form_screen.dart
  screens/inspection_detail_screen.dart
  screens/template_editor_screen.dart
  widgets/result_toggle.dart
  widgets/photo_picker_widget.dart
```

### 3. pubspec.yaml 교체

제공된 `pubspec.yaml`로 교체 후:

```bash
flutter pub get
```

### 4. Android 권한 설정

`android/app/src/main/AndroidManifest.xml` 파일에 `<manifest>` 태그 안, `<application>` 태그 **바깥**에 추가:

```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="29"/>
```

`<application>` 태그 안에 추가:
```xml
<provider
    android:name="androidx.core.content.FileProvider"
    android:authorities="${applicationId}.fileprovider"
    android:exported="false"
    android:grantUriPermissions="true">
    <meta-data
        android:name="android.support.FILE_PROVIDER_PATHS"
        android:resource="@xml/file_paths"/>
</provider>
```

`android/app/src/main/res/xml/file_paths.xml` 파일 생성:
```xml
<?xml version="1.0" encoding="utf-8"?>
<paths>
    <external-path name="external_files" path="."/>
    <cache-path name="cache" path="."/>
</paths>
```

### 5. iOS 권한 설정

`ios/Runner/Info.plist` 파일의 `<dict>` 태그 안에 추가:

```xml
<key>NSCameraUsageDescription</key>
<string>현장 점검 사진을 촬영하기 위해 카메라 접근이 필요합니다</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>현장 점검 사진을 첨부하기 위해 사진 라이브러리 접근이 필요합니다</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>점검 사진을 저장하기 위해 사진 라이브러리 접근이 필요합니다</string>
```

### 6. 실행

```bash
# iOS
flutter run -d ios

# Android
flutter run -d android
```

---

## 화면 구성

```
홈 화면
 ├── 필터 (장소 / 날짜)
 ├── 점검 목록 (날짜, 장소, 완료율)
 ├── [새 점검] FAB
 └── [설정 아이콘] → 점검표 편집

점검 입력 화면
 ├── 날짜 선택
 ├── 장소 / 점검자 입력
 ├── 대분류별 항목 (접기/펼치기)
 │    └── 각 항목: Y/N/NA 토글 + 특이사항 + 사진
 └── 종합 의견

점검 상세 화면
 ├── 결과 요약 (Y/N/NA/미점검 통계)
 ├── 항목별 결과 + 특이사항 + 사진
 ├── [수정] 버튼
 └── [내보내기] PDF / Excel 선택

점검표 편집
 ├── 대분류 드래그 순서 변경
 ├── 항목 드래그 순서 변경
 └── 추가 / 이름 수정 / 삭제
```

---

## 기술 스택

| 역할 | 패키지 |
|------|--------|
| 로컬 DB | sqflite |
| 상태 관리 | provider |
| 사진 촬영/선택 | image_picker |
| PDF 생성 | pdf + printing |
| Excel 생성 | excel |
| 파일 공유 | share_plus |
| 고유 ID | uuid |
| 날짜 형식 | intl |

---

## 데이터 저장 위치

- 데이터베이스: 앱 내부 SQLite (`field_inspection.db`)
- 사진: 앱 Documents 폴더 (`/photos/`)
- 앱 삭제 시에만 데이터 초기화됨

---

## 향후 추가 가능한 기능

- [ ] JSON 백업/복원 기능
- [ ] 점검 서명란 추가
- [ ] 불량(N) 항목 요약 페이지
- [ ] 앱 잠금 (PIN/생체인식)
- [ ] 다국어 지원
