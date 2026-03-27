# iOS Release Signing Checklist (TestFlight)

## Status atual detectado

- Projeto: `PsyManager.xcodeproj`
- `CODE_SIGN_STYLE = Automatic` em Debug/Release
- `PRODUCT_BUNDLE_IDENTIFIER = com.franciscomarcondes.psymanager`
- `DEVELOPMENT_TEAM` nao esta definido no `project.pbxproj`
- Erro atual de CLI: "Signing for PsyManager requires a development team"

## Passo a passo (Xcode)

1. Abra `PsyManager.xcodeproj` no Xcode.
2. Selecione o target `PsyManager`.
3. Va em `Signing & Capabilities`.
4. Em `Team`, selecione sua equipe Apple Developer.
5. Em `Bundle Identifier`, confirme ou ajuste para um ID unico da sua conta.
6. Em `Signing Certificate`, mantenha `Apple Development` para Debug e `Apple Distribution` para Release/Archive.
7. Em `Automatically manage signing`, mantenha ativo (recomendado).
8. Confirme que o mesmo Team esta aplicado em Debug e Release.

## Conta e portal Apple (se necessario)

1. Verifique no developer portal se o App ID existe para o bundle.
2. Se for novo bundle ID, deixe o Xcode criar automaticamente provisioning profiles.
3. Garanta que sua conta tenha permissao para certificados e profiles.

## Validacao local

### 1) Build simulator (sem assinatura)

```bash
xcodebuild -project PsyManager.xcodeproj -scheme PsyManager -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO
```

### 2) Build release para device generico (com assinatura)

```bash
xcodebuild -project PsyManager.xcodeproj -scheme PsyManager -configuration Release -destination 'generic/platform=iOS' build
```

### 3) Archive para TestFlight

No Xcode:

1. Product -> Archive
2. Organizer -> Distribute App -> App Store Connect -> Upload

## Critério de pronto

- Build Release sem erro de signing
- Archive concluido
- Upload aceito no App Store Connect
- Build visivel no TestFlight
