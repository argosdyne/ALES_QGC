# 작업 인계 (handoff) — AQGC Simple UI

다른 PC에서 이어서 작업하기 위한 현황 정리입니다. **2026-11-19 기준**입니다.
작업 규칙과 결정 사항의 원본은 `CLAUDE.md`, 고급 모드 개편 기록은 `custom/docs/TASK-advanced-mode-redesign.md`,
화면별 파일 목록은 `custom/res/Simple/README.md`입니다. 이 문서는 그 위에 "지금 어디까지 왔고 무엇이 남았는지"만 적습니다.

> 이 저장소는 **공개(public)** 입니다. 이 문서와 커밋에 개인 정보(이메일, 개인 폴더 경로 등)를 넣지 마세요.

## 1. 저장소 · 브랜치 · PR

| 항목 | 상태 |
|---|---|
| 작업 브랜치 | `feature/aqgc-simple-v1` (원격과 같음, 최신 커밋은 이 문서를 넣은 커밋) |
| PR | **#311** → `Argos_Stable4.4`, **draft**. 병합하지 않습니다(사용자 지시) |
| CI | `4e145e35d` 기준 Windows Release, Android 32/64-bit Release **성공**. "Deploy Docs"는 매번 실패하는 기존 문제(옛 upload-artifact v3) |
| 기반 브랜치 동기화 | 2026-11-18 `Argos_Stable4.4`의 #308–#310, #314, #315를 병합(`c17723f3c`). 충돌은 `PhotoVideoControl.qml` 1개 — 클래식 UI 삭제로 없앤 파일이라 삭제 유지 |
| #316 (2026-11-19) | SD 카드 없을 때 촬영·녹화 시작 거부(`CodevCameraControl.cc`)만 cherry-pick(`13502145f`). Simple 카메라 레일에 SD 상태 표시(`0d908aa8a`, Figma 99 Components "ui/CameraRail · state: No SD card") |
| 2026-11-19 병합 | `Argos_Stable4.4`의 #312, #317–#320 병합. 충돌 9개: 지운 클래식 파일(Elistair 패널·설정, LiDAR 패널·표시기·연결 페이지, `FlyViewOverlay.qml`)은 삭제 유지, `custom.qrc`·`FlyView.qml`·`MainRootWindow.qml`은 우리 쪽 유지 |
| LiDAR 2단계 (2026-11-19) | #318/#319 감시자 4개를 `MainRootWindow`에서 로드, Simple 화면 연결(Figma S102 경고·위험, S103 무응답, S17/S51/S53 노트). SITL + 가짜 LiDAR(`aqgc-build/fakelidar.py`)로 시작 거부, 경고, 위험, 배너에서 정지, 무응답·복구, S53 자동, 임무 자동 시작·정지, 궤적 확인 |

지켜야 할 것:
- **`Argos_Stable4.4`에 push 금지, PR #311 병합 금지.**
- push할 때마다 CI(Windows, Android)를 확인하고 PR #311 설명(커밋 표)을 갱신합니다.
- 커밋은 주제별로 작게, `git -c user.name=Claude -c user.email=noreply@anthropic.com commit` 형식을 써 왔습니다
  (이 PC에 git 사용자 정보가 없음). 메시지 끝에 `Co-Authored-By: Claude ...` 줄.
- 화면 변경은 **Figma 먼저**(파일 `AQGC-simpler`, key `p7d3GuBZaJNSj8zpBUlaSj`, 페이지 `01 Screens`, 현재 S01–S103), 그다음 코드.
- 새 QML 파일은 `custom/custom.qrc`(prefix `/simple`)와 `custom/res/Simple/qmldir` 두 곳에 등록.
- 빌드가 실제로 쓰는 qrc는 **`custom/qgroundcontrol.qrc`**(손으로 고친 파일). `custom/updateqrc.py`로 다시 만들지 마세요.

## 2. 2026-11-19 세션에서 한 일

| 커밋 | 내용 |
|---|---|
| `b918c52e5` `a04d43456` `bc7e41c94` | 3장 B 정리: 재시작 토스트, mainWindow 패널 플래그 삭제, CodevCameraVisual TypeError |
| `13502145f` `0d908aa8a` | #316 cherry-pick(SD 카드 없으면 촬영 거부) + 카메라 레일 SD 상태 표시(Figma 99 Components) |
| `c2270766d` | `Argos_Stable4.4` 병합(#312, #316–#320), 지운 클래식 파일 9개 충돌은 삭제·우리 쪽 유지 |
| `956a8791f` | YellowScan LiDAR 2단계(Figma S102, S103 + S17/S51/S53 노트), SITL + 가짜 LiDAR 시험 |

- 리뷰·인계서 AGD-DEV-ALQGC-401(D01, Claude Docs) 작성 — PR #311 리뷰용 변경 요약·코어 변경·시험 체크리스트.
- CI: `7710a4b6a` 기준 Windows, Android 성공.

## 2-1. 2026-11-18 세션에서 한 일

**1단계: 클래식 화면에만 있던 기능을 Simple 화면으로 옮김**

| 커밋 | Figma | 내용 |
|---|---|---|
| `bb70e3234` | S93–S96 | 수동 연결(시리얼/UDP/TCP, `SimpleManualLinks.qml`), RTK 시리얼 소스, USB 게임패드(`SimpleGamepad.qml`), 사용자 동작(Custom actions) |
| `3ee40d209` | S97 | 기체 설정 › 임무(MIS_OPTIONS, `SimpleSetupMission.qml`) |
| `b3a572c5` | S98 | 화면 조종 스틱을 Simple 비행 화면으로 이동 |
| `5b17c39b2` | S99 | 설정 › 페이로드 › Vision LiDAR(BirdCom 장애물 센서) |
| `4a3d179b2` | S100, S101 | 카메라 전체 설정(`SimpleCameraAll.qml`: 해상도·파일 형식 등 카메라가 알려 주는 설정, 열화상 보기, 영상 맞춤, SD 포맷, 카메라 초기화), 기체 설정 › 짐벌의 서보 짐벌(출력 SERVOn_FUNCTION 7/8/6, PWM 범위, 반전, 롤·팬 범위, 시작 모드) |
| `43b77e7c7` | (S50) | SAFE-T 전원 상실 배너에서 "테더에 연결된 드론 확인"(`associateNoPowerVehicle`). 단계 B에서 지운 클래식 테더 패널에만 있던 기능 |

사용자 결정(2026-11-18): Rajant 불필요. YellowScan LiDAR 설정, SAFE-T 스테이션 설정, ArduPilot Remote Support는 **만들지 않고 버림**(안내 문구 삭제).

**2단계: 클래식 UI 삭제**

| 커밋 | 단계 | 내용 |
|---|---|---|
| `4517d1d2a` | A | 메인 창 껍데기(툴바, 도구 대화상자·서랍, 클래식 닫기 버튼, GeoZoneMakeView 등). `simpleUI`는 항상 true |
| `b3a572c52` | B | 비행 화면 클래식 위젯 레이어 |
| `a2d8b5294` | — | 클래식 위젯에서만 동작하던 비행 화면 설정 삭제(체크리스트, 나침반 옵션) |
| `23cc56619` | C | 임무 계획 화면의 도구 막대·오른쪽 패널·편집기 |
| `403f7edb0` | D1 | 어디서도 불러올 수 없는 QML 129개(약 26,000줄) 삭제 |

남긴 것: MainRootWindow, FlyView/PlanView, GuidedActionsController, PlanMasterController, C++ 컨트롤러들.

**시험 결과**
- 로컬 Release 빌드 오류 없음, Qt Quick 테스트 146개 통과(17:33 실행분), 정적 검사(`custom/tests/simple/static_checks.py`) 실패 0.
- SITL(회사 펌웨어 Z01.07.00EASA, ArduPilot 4.5.1)에서: 수동 TCP 연결, 사용자 동작(servo9 1900), MIS_OPTIONS, 이륙 10 m·착륙,
  임무/펜스/랠리 편집, 짐벌 서보 출력 지정·이동·PWM·반전(드론 매개변수로 확인).
- S100은 SITL에 카메라가 없어 **가짜 MAVLink 카메라**(4장 `cam.py`)로 시험: 설정 변경, SD 포맷, 초기화 명령이 카메라에 도착함을 확인.

## 3. 남은 일

**A. 결정 대기 (사용자에게 물어볼 것)**
- **D2**: C++가 아직 이름으로 가리키는 클래식 QML 페이지(APM 기체 설정 페이지, 설정·분석 페이지, 미션 항목 편집기, 툴바 표시기)는
  앱에서 열 수 없지만 파일은 남아 있습니다. 지우려면 C++ 참조를 끊어야 해서 코어 수정이 커집니다. 지금 할지, 개발자 리뷰 뒤로 미룰지.
  `reach.py --cpp-roots`(4장)로 대상 목록을 다시 뽑을 수 있습니다.

- **Elistair TCP/UDP 연결 화면** (#317, 2026-11-19 병합): C++(`ElistairStationManager`)만 들어옴. 연결 방식 선택 화면
  (클래식 설정은 삭제됨)이 Simple S52/S16에 필요. Figma 먼저.

**B. 작은 정리 — 2026-11-19 완료**
1. ~~재부팅 필요 메시지 상자~~ → Simple 토스트(`b918c52e5`, Figma S60/S101 노트). S101·S60은 자체 안내만 표시. 실기·SITL에서 토스트 표시는 아직 화면으로 확인하지 않음.
2. ~~`mainWindow` 패널 플래그~~ 삭제(`a04d43456`). `ysOpenPanelOnConnect` 설정은 남김(이제 효과 없음).
3. ~~`CodevCameraVisual.qml` TypeError~~ 수정(`bc7e41c94`): 일반 MAVLink 카메라에서는 Codev 전용 값을 읽지 않음.
- 남은 메모: Figma "UX notes · S101" 제목이 "S101 페이로드 › Vision LiDAR"로 잘못 붙어 있음(내용은 짐벌). 확인 후 고칠 것.

**C. 실기·장비 시험 (SITL로 못 한 것)**
- USB 게임패드(S95), Vision LiDAR(S99), RTK 시리얼 데이터, SAFE-T 전원 상실 시 "예, 이 드론입니다"(S50),
  실제 회사 카메라(R3 등)에서 S100과 SD 포맷.

**D. PR #311 리뷰 준비**
- 변경 요약 + 시험 체크리스트(C 항목 포함)를 개발자에게 넘길 문서로 정리.

추천 순서: B → D → (리뷰 결과를 보고) A. C는 장비가 있는 사람에게 D의 체크리스트로 부탁.

## 4. 다른 PC에서 시작하기

**저장소**
```
git clone <원격 URL> ales_qgc        # 또는 기존 클론에서 git fetch && git checkout feature/aqgc-simple-v1 && git pull
```

**로컬 빌드·시험 도구는 저장소에 없습니다.** 이 PC의 `C:\Users\<사용자>\aqgc-build` 폴더에 있던 스크립트를
`aqgc-claude-code-handoff_2026-11-18.zip`(저장소 밖, `works` 폴더)으로 묶었습니다. 새 PC의 같은 위치에 풀고,
사용자 이름이나 저장소 경로가 다르면 각 스크립트 첫 줄의 경로(`set B=...`, `subst Q: ...`, `/mnt/c/Users/...`)를 고치세요.

| 파일 | 용도 |
|---|---|
| `build_rel.bat` | Release 빌드(`rbuild\`). 저장소를 `subst Q:`로 잡아 빌드(경로에 공백이 있어서) |
| `tests.bat` | Simple UI Qt Quick 테스트 → `tests.txt`. **PowerShell에서 `cmd /c ...\tests.bat`로 실행**(Git Bash의 `cmd //c`로는 실행되지 않고 옛 결과가 남은 적 있음). 끝난 뒤 `tests.txt` 시각 확인 |
| `ui.ps1` | UI 구동: `start [args\|none] [name]`, `pin`, `tap x y`, `drag`, `slide`, `type`, `key`, `shot name`, `stop`. 스크린샷·로그는 `runs\` |
| `sitl.sh`, `aqgc-sitl.parm` | WSL(Ubuntu-22.04)에서 회사 ArduCopter SITL 실행(`~/APM4.5` 빌드 필요, 4시간 제한). Git Bash: `MSYS_NO_PATHCONV=1 wsl -d Ubuntu-22.04 -- bash /mnt/c/.../sitl.sh run` |
| `sitl.py`, `servo.py` 등 | pymavlink 도우미(TCP 5762): `param NAME..`, `set NAME VALUE`, `takeoff`, `mode` |
| `add_ts.py` | 한국어 번역 추가: `python add_ts.py translations/qgc_simple_ko_KR.ts <json>` |
| `tools/reach.py`, `deld1.py`, `xcheck.py`, `missing.py`, `stale*.py` | 클래식 삭제 때 쓴 도구(도달 가능성 분석, 삭제, 교차 확인, 번역 정리) |
| `tools/cam.py`, `tools/camdef/testcam.xml` | 가짜 MAVLink 카메라(S100 시험). 정의 파일은 Windows에서 `python -m http.server 8765 --bind 127.0.0.1 --directory camdef`로 제공 |
| `fakelidar.py`, `fakelidar.json` | 가짜 YellowScan LiDAR(WSL, SITL TCP 5762, compid 25). json으로 무응답·USB 부족/가득·과열·시작 거부 전환 |

새 PC에 필요한 것: Visual Studio 2022 Build Tools(C++), Qt 5.15.2 msvc2019_64(aqtinstall), jom, Python 3,
WSL Ubuntu-22.04 + 회사 ArduPilot 트리(`~/APM4.5`, `./waf configure --board sitl && ./waf copter`) + pymavlink, `gh` CLI(로그인).

**UI 시험 때 반드시**
- 앱 설정 파일(`%APPDATA%\argosdyne.org\Ales QGC Daily.ini`)의 `savePath`가 실제 OneDrive 폴더를 가리킵니다.
  시험 전에 ini를 백업하고 `savePath`를 임시 폴더로 바꾼 뒤, 끝나면 백업으로 되돌립니다. 실제 데이터를 건드리지 않습니다.
- SITL 매개변수를 바꿨으면 시험 뒤 원래 값으로 되돌립니다(2026-11-18 짐벌 시험 값은 모두 복구함).

**Claude Code 시작 지시 예**
```
handoff.md와 CLAUDE.md를 읽고, 3장 "남은 일"의 B부터 진행해 줘. D2(3장 A)는 먼저 나에게 물어봐.
```
