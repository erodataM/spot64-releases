Unicode True

!include "MUI2.nsh"
!include "LogicLib.nsh"

!ifndef RELEASE_TAG
  !error "RELEASE_TAG must be provided to makensis"
!endif

!ifndef OUTPUT_FILE
  !define OUTPUT_FILE "Spot64-Beta-Setup.exe"
!endif

!ifndef CORPUS_TAG
  !define CORPUS_TAG "v0.1.0-beta.7"
!endif

Name "Spot64 Beta"
OutFile "${OUTPUT_FILE}"
RequestExecutionLevel user
ShowInstDetails show
SetCompressor /SOLID lzma
BrandingText "Spot64 Beta"

!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TITLE "Installer Spot64 Beta"
!define MUI_WELCOMEPAGE_TEXT "Cet assistant installe l'application et son corpus échiquéen vérifié.$\r$\n$\r$\nLe téléchargement représente environ 5 Go et peut reprendre après une interruption."
!define MUI_FINISHPAGE_TITLE "Spot64 est prêt"
!define MUI_FINISHPAGE_TEXT "L'application et le corpus ont été vérifiés et installés."
!define MUI_FINISHPAGE_RUN "$LOCALAPPDATA\Libase\desktop.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Lancer Spot64"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_LANGUAGE "French"
!insertmacro MUI_LANGUAGE "English"

Section "Spot64 Beta" MainSection
  SetOutPath "$PLUGINSDIR"
  File /oname=install-spot64-beta.ps1 "..\scripts\install-spot64-beta.ps1"

  MessageBox MB_ICONINFORMATION|MB_OK \
    "Cette version bêta n'est pas encore signée.$\r$\n$\r$\nSi votre antivirus bloque l'installation, annulez, autorisez explicitement Spot64 ou suspendez temporairement sa protection en temps réel, puis réactivez-la immédiatement après l'installation."

  DetailPrint "Préparation de Spot64 ${RELEASE_TAG}..."
  nsExec::ExecToLog 'powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PLUGINSDIR\install-spot64-beta.ps1" -Tag "${RELEASE_TAG}" -CorpusTag "${CORPUS_TAG}" -SilentApplicationInstall -SkipApplicationLaunch'
  Pop $0
  ${If} $0 != 0
    MessageBox MB_ICONSTOP|MB_OK \
      "L'installation de Spot64 n'a pas abouti.$\r$\n$\r$\nLe journal détaillé est visible dans cette fenêtre. Vous pouvez relancer cet installateur : les volumes déjà vérifiés seront réutilisés."
    SetErrorLevel $0
    Abort
  ${EndIf}
SectionEnd
