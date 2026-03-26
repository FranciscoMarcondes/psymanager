# Deployment Configuration Summary - PsyManager

**Last Updated**: March 26, 2026  
**Status**: Tier 5 (UX/Commercial Readiness) - Ready for TestFlight & Vercel Production

---

## 📊 Quick Status

| Component | Status | Platform | Notes |
|-----------|--------|----------|-------|
| **Web Backend** | ✅ Ready | Vercel (Next.js 16) | Configured, build tested |
| **iOS App** | ✅ Ready | Apple App Store (via TestFlight) | Compiled, needs signing |
| **Database** | ✅ Ready | Supabase | Schema migrated, RLS enabled |
| **CI/CD (Web)** | ⏳ Partial | Vercel | Auto-deploy on push, no GitHub Actions |
| **CI/CD (iOS)** | ❌ None | - | Manual Xcode builds only |
| **Environment Config** | ✅ Documented | Both | .env.local.example provided |

---

## 🌐 WEB BACKEND (Next.js 16)

### Deployment Platform
- **Host**: Vercel (production domain: `web-app-eight-hazel.vercel.app`)
- **Framework**: Next.js 16.2.0 with TypeScript
- **Runtime**: Node.js (Vercel managed)

### Configuration Files

#### [vercel.json](web-app/vercel.json)
```json
{
  "buildCommand": "npm run build",
  "outputDirectory": ".next",
  "framework": "nextjs"
}
```
**Settings**: 
- Build: `npm run build`
- Output: `.next` directory
- Rewrites for auth endpoints configured

#### [next.config.ts](web-app/next.config.ts)
- Remote image optimization enabled
- Allowed domains: Spotify, Google, Instagram/Meta
- TypeScript configured

#### [package.json](web-app/package.json)
**Build Scripts**:
```bash
npm run dev      # Local development → http://localhost:3000
npm run build    # Production build to .next/
npm run start    # Production server start
npm run lint     # ESLint validation
```

**Key Dependencies**:
- `next`: 16.2.0
- `next-auth`: 4.24.13 (OAuth provider)
- `@supabase/supabase-js`: 2.99.3 (DB client)
- `bcryptjs`: 3.0.3 (password hashing)
- `react`: 19.2.4 & `react-dom`: 19.2.4

### Environment Configuration

#### Required Environment Variables
See [.env.local.example](web-app/.env.local.example):

**Authentication** (NextAuth):
```env
NEXTAUTH_SECRET=<strong-random-secret>          # Generated with: openssl rand -base64 32
NEXTAUTH_URL=http://localhost:3000              # Dev: local, Prod: vercel domain
```

**OAuth Providers**:
```env
# Spotify (free tier)
SPOTIFY_CLIENT_ID=<from-spotify-dashboard>
SPOTIFY_CLIENT_SECRET=<from-spotify-dashboard>

# Google/YouTube (free tier)
GOOGLE_CLIENT_ID=<from-google-console>
GOOGLE_CLIENT_SECRET=<from-google-console>

# Meta/Facebook/Instagram
FACEBOOK_CLIENT_ID=<from-meta-app-dashboard>
FACEBOOK_CLIENT_SECRET=<from-meta-app-dashboard>
INSTAGRAM_CLIENT_ID=<optional>
INSTAGRAM_CLIENT_SECRET=<optional>
```

**Database** (Supabase):
```env
SUPABASE_URL=https://<project>.supabase.co
SUPABASE_SERVICE_ROLE_KEY=<server-only-secret>
```

**AI Services**:
```env
OPENAI_API_KEY=<for-gpt-4o-mini-and-dalle>
OPENAI_MODEL=gpt-4o-mini                        # Default, can override
GEMINI_API_KEY=<fallback-for-chat>
GEMINI_MODEL=gemini-2.5-flash
GEMINI_IMAGE_MODEL=gemini-3.1-flash-image-preview
```

**Mobile-Specific**:
```env
MOBILE_SYNC_SECRET=<strong-random-secret>       # JWT signing for iOS tokens
MOBILE_SYNC_USER_ID=<optional-for-legacy-mode>  # Single fixed user (dev only)
```

**Optional APIs**:
```env
NEXT_PUBLIC_KIWI_API_KEY=<for-flight-search>    # Free tier available
NEXT_PUBLIC_INSTAGRAM_ENABLED=false             # Toggle Instagram OAuth
```

### API Routes
- **Auth Endpoints**: `/api/auth/*` (NextAuth)
  - `/api/auth/callback/spotify`, `/callback/google`, `/callback/facebook`
- **Mobile Auth**: `/api/auth/local-login`, `/api/auth/mobile-facebook-callback`
- **Sync Endpoint**: `/api/mobile/sync` (bidirectional)
- **Content/Planning**: `/api/content-plan/`, `/api/editor/`
- **Manager AI**: `/api/manager/`, `/api/generate-*` (images, covers)
- **Workspace**: `/api/workspace/sync-health`

### CI/CD (Web)
- **Pipeline**: Automatic on Git push to main
- **Provider**: Vercel native (no GitHub Actions)
- **Deployments**: Automatic staging + production
- **Build Time**: ~2-3 minutes

**No GitHub Actions configured** - relies on Vercel's native deployment.

### Database & Migrations
- **Provider**: Supabase (PostgreSQL)
- **Migrations**: [database-migrations/](database-migrations/)
  - `002_learned_facts.sql` - Audit trail for learned facts feature
  - `schema.sql` - Core tables: `psy_users`, `psy_workspace`, `audit_logs`, `learned_facts_sync_log`

---

## 📱 iOS APP (SwiftUI)

### Project Configuration
- **Project File**: `PsyManager.xcodeproj`
- **Framework**: SwiftUI + MVVM
- **Minimum iOS**: 17.0+
- **Language**: Swift 5

### Build Configuration

**Build Command** (Xcode CLI):
```bash
# Development (Simulator)
xcodebuild -project PsyManager.xcodeproj \
  -scheme PsyManager \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# Production (Device Archive)
xcodebuild -project PsyManager.xcodeproj \
  -scheme PsyManager \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  archive
```

### Signing & Capabilities
- **Team ID**: Not yet configured (needs Apple Developer account)
- **Bundle Identifier**: To be set in Xcode
- **Signing Method**: Manual (requires Developer Certificate + Provisioning Profile)
- **Required Capabilities**:
  - ✅ Deep Link Support (`psymanager://` scheme)
  - ✅ OAuth Sign In (`ASWebAuthenticationSession`)
  - ✅ Keychain Storage (secure token persistence)
  - ✅ Network (URLSession)
  - ⏳ Camera (optional, not yet used)
  - ⏳ Microphone (optional, future enhancement)

### Key Services & Integration
- **Auth Service**: `WebAuthService` - Handles OAuth flow via `ASWebAuthenticationSession`
- **Sync Service**: Bidirectional sync with `/api/mobile/sync`
- **Local Storage**: SwiftData (native persistence)
- **Audit Trail**: `SyncAuditService` - logs all operations for conflict resolution

### Environment Configuration (iOS)
Set at runtime (no `.env` file for iOS):
1. **Scheme Edit → Run → Arguments → Environment Variables**:
   ```
   OPENAI_API_KEY=<if using local AI>
   API_BASE_URL=http://localhost:3000 (dev) or https://web-app-eight-hazel.vercel.app (prod)
   ```

2. **Deep Link Redirect**: `psymanager://auth?mobileToken=XXX&email=XXX&name=XXX`

### Deployment Steps

#### 1. Local Device (Simulator)
```bash
cd /Users/franciscomarcondes/Downloads/IOSSimuladorStarter
xcodebuild -project PsyManager.xcodeproj \
  -scheme PsyManager \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

#### 2. Physical Device (TestFlight/Production)
1. Connect iPhone to Mac
2. Trust the computer (on device)
3. Open `PsyManager.xcodeproj` in Xcode
4. Select device in top scheme dropdown
5. **Product → Archive**
6. **Organizer → Distribute App → TestFlight Upload**
   - Requires Apple Developer account & Team ID

#### 3. App Store Release
- Build via Xcode Archive → Distribute App
- Select "App Store Connect"
- App Review + Release

### CI/CD (iOS)
- **Status**: ❌ None configured
- **Current**: Manual Xcode builds
- **Future Option**: GitHub Actions (recommended for TestFlight automation)
  - Example: Trigger build on tag, auto-upload to TestFlight
  - Requires: Deployment certificates, provisioning profiles in GitHub Secrets

---

## 🗄️ DATABASE (Supabase)

### Setup
- **Type**: PostgreSQL (Managed)
- **Provider**: Supabase
- **Region**: Configurable during project creation
- **RLS**: Enabled on all user-facing tables

### Schema

#### Core Tables

**`psy_users`** - User accounts (legacy, may be deprecated)
```sql
user_id TEXT PRIMARY KEY
email TEXT UNIQUE
artist_name TEXT
password_hash TEXT
created_at TIMESTAMP
```

**`psy_workspace`** - Main data store (JSON + sync)
```sql
user_id TEXT PRIMARY KEY
payload JSONB -- Full workspace data (content plan, calendar, etc.)
updated_at TIMESTAMP
```

**`audit_logs`** - Sync operation audit trail
```sql
id UUID PRIMARY KEY
user_id TEXT (indexed)
operation TEXT -- 'pull', 'push', 'merge', 'error'
entity_type TEXT
device_id TEXT
changes_summary TEXT
conflict_detected BOOLEAN
resolution_strategy TEXT
status_code INT
error_message TEXT
sync_duration_ms INT
created_at TIMESTAMP (indexed)
```

**`learned_facts`** - AI-extracted facts from conversations
```sql
id UUID PRIMARY KEY
user_id UUID
content TEXT
category VARCHAR -- 'preference', 'pricing', 'location', etc.
confidence FLOAT
source VARCHAR -- 'chat_history'
extracted_at TIMESTAMP
created_at TIMESTAMP
-- RLS: Users see only their own facts
```

### Migration Files
- **Location**: [database-migrations/](database-migrations/)
- **Latest**: `002_learned_facts.sql`
- **Deployment**: Manual SQL execution in Supabase dashboard or via migrations CLI

### Connection

**Web Backend** uses: `@supabase/supabase-js` client
```typescript
import { getSupabaseAdminClient } from "@/lib/supabaseAdmin";
const supabase = getSupabaseAdminClient();
await supabase.from("audit_logs").insert([...]);
```

**iOS** uses: REST calls via `/api/mobile/sync` endpoint (no direct SDK)

---

## 🔐 Security & Secrets Management

### Local Development
- **File**: `.env.local` (never commit)
- **Template**: `.env.local.example` (provided)
- **Setup**: Copy example, fill secrets

### Production (Vercel)
1. **Vercel Dashboard** → Project Settings → Environment Variables
2. Add all secrets from `.env.local.example`
3. Set Environment: **Production**, **Preview**, **Development** as needed
4. Redeploy after adding/updating variables

### Keys Required for Full Feature Set
| Key | Purpose | Tier | Required? |
|-----|---------|------|-----------|
| `NEXTAUTH_SECRET` | NextAuth session signing | Free | ✅ Yes |
| `OPENAI_API_KEY` | GPT-4o-mini, DALL-E | Paid | ⏳ Optional (fallback: Gemini) |
| `GEMINI_API_KEY` | Fallback AI (chat, images) | Free | ✅ Highly recommended |
| `SPOTIFY_CLIENT_ID/SECRET` | Spotify OAuth | Free | ✅ Yes (music features) |
| `GOOGLE_CLIENT_ID/SECRET` | Google OAuth, YouTube | Free | ✅ Yes |
| `FACEBOOK_CLIENT_ID/SECRET` | Meta/Facebook OAuth | Free | ✅ Yes (mobile app uses) |
| `SUPABASE_URL` | Database connection | Free | ✅ Yes |
| `SUPABASE_SERVICE_ROLE_KEY` | DB admin access | Free | ✅ Yes |
| `MOBILE_SYNC_SECRET` | iOS JWT signing | Free | ✅ Yes |
| `GEMINI_IMAGE_MODEL` | AI image generation | Free | ⏳ Optional |
| `NEXT_PUBLIC_KIWI_API_KEY` | Flight search (Kiwi) | Free | ⏳ Optional |

---

## 🚀 Current Deployment Status

### ✅ What's Working
- Next.js web app builds successfully
- TypeScript builds without errors
- Supabase schema migrated
- OAuth configured (Spotify, Google, Facebook)
- Mobile sync API endpoint ready
- Deep link listener ready (iOS)
- Keychain integration (iOS)

### ⏳ What Needs Completion
1. **iOS Signing Certificate** - Requires Apple Developer account
2. **TestFlight Setup** - Upload archive, invite testers
3. **Production Environment Secrets** - Add to Vercel dashboard
4. **GitHub Actions (iOS CI/CD)** - Optional but recommended
5. **Database Backups** - Configure in Supabase
6. **Monitoring/Logging** - Set up error tracking (e.g., Sentry)

### ❌ What's Not Configured
- GitHub Actions for iOS (manual builds only)
- App Store submission (not required for TestFlight)
- Docker/K8s (Vercel handles this)
- Custom domain SSL (Vercel handles this)
- CDN for media (uses social provider CDNs)

---

## 📋 Deployment Checklist

### Before First Release

#### Web (Vercel)
- [ ] Verify all `.env` variables filled in Vercel dashboard
- [ ] Test production build locally: `npm run build && npm run start`
- [ ] Trigger deploy to staging branch
- [ ] Test OAuth flows on staging domain
- [ ] Monitor logs on Vercel dashboard
- [ ] Set up error tracking (e.g., Sentry)

#### iOS (TestFlight)
- [ ] Create Apple Developer account & Team
- [ ] Generate/upload signing certificates in Xcode
- [ ] Create App ID & Provisioning Profile
- [ ] Archive build: **Product → Archive**
- [ ] Upload to TestFlight via Organizer
- [ ] Add internal testers (your team)
- [ ] Test OAuth + deep links on real device
- [ ] Request App Review (if going to App Store)

#### Database (Supabase)
- [ ] Verify RLS policies enabled
- [ ] Create backup before production
- [ ] Set up automated backups (weekly/daily)
- [ ] Test sync conflict resolution
- [ ] Monitor audit_logs for errors

#### Post-Launch
- [ ] Monitor Vercel deployment metrics
- [ ] Check database query performance
- [ ] Monitor iOS crash reports
- [ ] Collect user feedback on sync reliability

---

## 🔗 Key Documentation References

- [OAUTH_PRODUCTION_SETUP.md](OAUTH_PRODUCTION_SETUP.md) - OAuth & device deployment steps
- [RELEASE_READINESS_FINAL.md](RELEASE_READINESS_FINAL.md) - Release validation checklist
- [TIER5_UX_COMMERCIAL_READINESS.md](TIER5_UX_COMMERCIAL_READINESS.md) - Commercial readiness criteria
- [TIER3_SETUP.md](TIER3_SETUP.md) - Sync & conflict resolution details
- [web-app/.env.local.example](web-app/.env.local.example) - Full environment variable reference

---

## 🎯 Recommended Next Steps

1. **Immediate**:
   - [ ] Set Apple Developer Team ID in Xcode
   - [ ] Generate iOS signing certificates
   - [ ] Fill production environment variables in Vercel

2. **This Week**:
   - [ ] Upload first TestFlight build
   - [ ] Deploy web backend to Vercel production
   - [ ] Test end-to-end OAuth on physical device

3. **Next Sprint**:
   - [ ] Set up GitHub Actions for iOS (auto-build on tag)
   - [ ] Implement error tracking (Sentry/similar)
   - [ ] Create app store submission checklist

---

**Questions?** See individual `.md` files in root directory for detailed setup instructions.
