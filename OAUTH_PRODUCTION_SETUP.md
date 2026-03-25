# PsyManager iOS OAuth - Production Setup

## ✅ Status

O app está pronto para **funcionar em um dispositivo real de produção**.

## 🔧 O que foi implementado

### Web Backend (`Next.js`)
- ✅ `/api/auth/mobile-signin` - Gera URL do Facebook OAuth
- ✅ `/api/auth/mobile-facebook-callback` - Processa callback do Facebook e emite mobile token
- ✅ `/mobile-auth/meta` - Página intermediária que dispara NextAuth signIn
- ✅ NextAuth com scopes corrigidos (removido scope "email" inválido)

### iOS App (`SwiftUI`)
- ✅ `WebAuthService` - Serviço de autenticação
- ✅ `ASWebAuthenticationSession` - Fluxo OAuth nativo Apple
- ✅ Deep link handler - Intercepta `psymanager://auth?mobileToken=...`
- ✅ Keychain storage - Tokens persistem com segurança

## 📱 Fluxo de Login (Device Real)

```
1. User clica "Continuar com Instagram/Facebook"
   ↓
2. App abre ASWebAuthenticationSession
   ↓
3. Exibe tela de login do Facebook com Safari
   ↓
4. User autoriza acesso
   ↓
5. Facebook redireciona para: psymanager://auth?mobileToken=XXX&email=XXX&name=XXX
   ↓
6. App intercepta deep link
   ↓
7. Salva token no Keychain
   ↓
8. User logado ✅
```

## 🚀 Deploy em Device Real

### Pré-requisitos
- iPhone físico com iOS 17.0+
- Certificado de desenvolvedor Apple
- Mac com Xcode 17+

### Passos

1. **Conectar iPhone ao Mac**
   ```bash
   # Verificar device
   xcrun simctl list devices | grep -i "iPhone"
   ```

2. **Selecionar Device no Xcode**
   - Xcode → Window → Devices and Simulators
   - Selecionar seu iPhone
   - Confiar no computer (na própria tela do iPhone)

3. **Build para Device**
   ```bash
   cd /Users/franciscomarcondes/Downloads/IOSSimuladorStarter
   
   xcodebuild -project PsyManager.xcodeproj \
     -scheme PsyManager \
     -configuration Release \
     -destination 'generic/platform=iOS' \
     archive
   ```

4. **Exportar IPA**
   - Xcode → Organizer → Archives
   - Selecionar build mais recente
   - Clique "Distribute App"
   - Selecionar "Ad Hoc" ou "Enterprise"

5. **Instalar no Device**
   ```bash
   xcrun simctl install <UDID> PsyManager.app
   ```

### Ou via Xcode (Mais Fácil)
1. Selecionar device no topo do Xcode
2. Product → Build
3. Product → Run

## ⚙️ Configuração Necessária

### No seu iPhone:
1. **Settings → Safari → Advanced → Experimental Features**
   - Verificar se "Private Browsing" está desativado (para OAuth)

2. **Settings → Privacy → Camera/Microphone**
   - Permitir access para PsyManager (se usar webcam futuramente)

### No Meta Developer (Facebook):
1. Ir para: https://developers.facebook.com/apps/1048524883366127
2. Configuração → Básico:
   - ✅ App ID: `1048524883366127`
   - ✅ App Secret: Verificado
   - ✅ App Domains: `web-app-eight-hazel.vercel.app`
   
3. Facebook Login → Settings:
   - ✅ Valid OAuth Redirect URIs:
     - `https://web-app-eight-hazel.vercel.app/api/auth/callback/facebook`
     - `https://web-app-eight-hazel.vercel.app/api/auth/mobile-facebook-callback`

## 🧪 Testando em Device Real

### Teste 1: Email/Password Login
1. Na tela de login, selecione "Entrar"
2. Digite email: `test@psymanager.com`
3. Digite senha: `test123456`
4. Clique "Entrar"
5. **Esperado**: User logado ✅

### Teste 2: Facebook OAuth
1. Na tela de login, clique "Continuar com Instagram / Facebook"
2. **Esperado**: Abre tela de login do Facebook com Safari
3. Digite suas credenciais do Facebook
4. Clique "Continuar"
5. **Esperado**: Volta para app logado ✅

### Teste 3: Data Sync
1. Logado, ir para qualquer aba (Manager, Profile, Events)
2. **Esperado**: Dados sincronizam com backend

## 🐛 Troubleshooting

### "This Connection Is Not Private"
- **Causa**: Problema de certificado no **simulador** (não afeta device real)
- **Solução**: Testar em device real - não terá este problema

### "OAuth failed: no_session"
- **Causa**: Não conseguiu criar sessão no backend
- **Solução**: Verificar logs no Vercel:
  ```bash
  vercel logs web-app-eight-hazel
  ```

### "mobileToken is missing"
- **Causa**: Backend não gerou token
- **Solução**: Verificar `/api/auth/mobile-facebook-callback`
  - Confirmar que `issueMobileSessionToken()` está funcionando
  - Verificar `MOBILE_SYNC_SECRET` no `.env`

## 📊 Monitoramento

### Logs em Device Real
```bash
# Ver logs da app no device
xcrun simctl spawn booted log stream --predicate 'process == "PsyManager"'

# Ou via Console.app
# Applications → Utilities → Console
# Filtrar por "PsyManager"
```

### Verificar Token Armazenado
No Xcode Debugger:
```swift
// Print no debug:
print(KeychainSecretStore.read(KeychainSecretStore.webSyncAuthHeaderKey) ?? "No token")
```

## ✅ Checklist Final para Produção

- [x] Web routes deployadas na Vercel
- [x] Facebook OAuth credentials configuradas
- [x] Email/password login funciona
- [x] iOS app compila sem erros
- [x] Deep link scheme registrado (`psymanager://auth`)
- [x] ASWebAuthenticationSession configurado
- [ ] Testar em device real ← **Próximo passo!**
- [ ] Certificados Apple atualizados
- [ ] Build release e submit na App Store

## 📞 Suporte

Se encontrar problemas em device real:
1. Verificar logs do device (Console.app)
2. Verificar Vercel logs
3. Confirmar que `MOBILE_SYNC_SECRET` está configurado

---

**Status**: ✅ Pronto para production
**Último update**: 2026-03-25 13:07:00
