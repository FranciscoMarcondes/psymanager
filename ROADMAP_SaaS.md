# 🚀 PsyManager — Roadmap SaaS & Profissionalização

**Status**: MVP completo + Premium features entregues | **Objetivo**: Produto escalável, multi-tenant, monetizado

---

## 📋 ÍNDICE
1. [Gap Analysis](#1-gap-analysis) — Funcionalidades faltando
2. [Multi-User + Meta Login](#2-multi-user--meta-login) — Sem quebrar testes
3. [Remover Mocks](#3-remover-mocks) — Dados reais
4. [Modelo SaaS](#4-modelo-saas) — Cobrança e licenças
5. [APIs Externas](#5-liberação-de-apis) — Meta, Spotify
6. [App Store](#6-publicação-app-store) — Passo a passo
7. [Checklist Profissional](#7-checklist-profissional) — Tudo que falta
8. [Sugestões + Recursos](#8-sugestões-para-melhorar) — Aumentar valor

---

## 1. GAP ANALYSIS

### ⚠️ **Funcionalidades Faltando / Não Interligadas**

#### **A. DADOS REAIS (Crítico)**
| Gap | Impacto | Solução |
|-----|--------|---------|
| **Spotify insights são MOCK** | Usuários veem dados fake | Implementar Web API real (2-3h) |
| **Instagram insights são MOCK** | Dados fake para IA | Implementar Graph API real (2h) |
| **YouTube não retorna vídeos** | Feature incompleto | Chamar YouTube Data API (1h) |
| **Manager IA usa fallback mock** | Sem personalização | Conectar OpenAI real + treino (3-4h) |
| **Geocoding funciona mas buscas são sample** | Resultado impreciso | Seed real de eventos por estado (1h) |

#### **B. FLUXOS NÃO INTERLIGADOS**
| Gap | Impacto | Solução |
|-----|--------|---------|
| **Content plan → Instagram scheduler** | Manual duplicate | Auto-sync para Meta Graph API (3h) |
| **Gigs → Calendar → Logistics** | Sem automação | Chainlinking automático (2h) |
| **Leads → Negociações → Contratos** | Dados desligados | Sync bidirecional (2h) |
| **Manager IA input → Gigs/Tasks Decision** | IA explora pouco | Implement decision graph (4h) |
| **Expenses → Break-even → Booking adviser** | Cálculos isolados | Unified financial engine (3h) |

#### **C. INTEGRAÇÕES FALTANDO**
| Integração | Impacto | Prioridade |
|-----------|--------|-----------|
| **WhatsApp Business API** | Não pode mandar mensagem | Alta (para contato com promoters) |
| **Calendly / Cal.com sync** | Não sincroniza bookings | Média |
| **Stripe / PagSeguro** | Sem pagamentos diretos | Alta (para cobranças) |
| **Twilio / Mensafone SMS** | Sem SMS alerts | Média |
| **Zapier / Make.com webhooks** | Não automatiza workflows | Média |
| **Discord/Telegram bot** | Sem notificações | Baixa |
| **Google Drive API** | Sem backup cloud | Média |

#### **D. SEGURANÇA / COMPLIANCE**
| Gap | Risco | Solução |
|-----|------|--------|
| **Sem 2FA** | Contas hackeadas | Implementar TOTP (1h) |
| **Sem rate limiting** | DDoS vulnerável | NextAuth rate limiter (1h) |
| **Sem audit log completo** | Não rastreável | Supabase audit via RLS (2h) |
| **Sem GDPR compliance** | Legal liability | Export/delete data endpoint (2h) |
| **Sem criptografia de senhas forte** | Risco de breach | Verificar bcrypt, migrar se necessário (1h) |
| **Sem device fingerprint** | Sem detecção fraude | Implement tracking (1h) |

---

## 2. MULTI-USER + META LOGIN

### **Objetivo**: Suportar múltiplos usuários com Meta login, **sem quebrar seu fluxo de testes**

### **Estratégia**

```
┌─────────────────────────────────────────┐
│  Sua Conta de Teste (PERMANENTE)        │
│  ❌ Não será removida/alterada          │
├─────────────────────────────────────────┤
│  Email: seu-email@seu-dominio.com      │
│  Meta Login: App Development Account    │
│  Status: ADMIN + SUPER_TESTER           │
│  Permissão: Chamar APIs em modo teste   │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  Novos Usuários (Production)            │
│  ✅ Login via Meta / Email              │
│  ✅ Dados isolados (Multi-tenant)       │
│  ✅ Limitações de trial                 │
└─────────────────────────────────────────┘
```

### **Implementação**

#### **Step 1: Adicionar `user_role` + `app_tier` ao `psy_users`**

```sql
ALTER TABLE psy_users ADD COLUMN (
  user_role VARCHAR(50) DEFAULT 'user',  -- 'admin', 'user', 'banned'
  app_tier VARCHAR(50) DEFAULT 'free',   -- 'free', 'trial', 'pro', 'enterprise'
  tier_expires_at TIMESTAMPTZ,           -- NULL = forever
  created_via VARCHAR(50) DEFAULT 'unknown',  -- 'email', 'spotify', 'instagram', 'meta'
  last_login_at TIMESTAMPTZ,
  subscription_id VARCHAR(200)           -- Stripe/Paddle subscription
);

-- Seu usuário de teste
UPDATE psy_users SET user_role = 'admin', app_tier = 'super_tester' 
WHERE email = 'seu-email@seu-dominio.com';
```

#### **Step 2: Implementar Meta Login (mantendo Spotify + Google)**

**Arquivo**: `web-app/src/lib/authOptions.ts`

```typescript
// NOVO: Meta OAuth Provider
// Meta agora redireciona para:
// 1. Login com Meta Account
// 2. Permissão para acessar Instagram Insights
// 3. Callback retorna user + instagram_access_token

export const authOptions: NextAuthOptions = {
  providers: [
    // ... existentes: Spotify, Google, Credentials
    
    // NOVO Meta Provider
    {
      id: "meta",
      name: "Meta (Instagram/Facebook)",
      type: "oauth",
      version: "2.0",
      authorization: {
        url: "https://www.facebook.com/v18.0/dialog/oauth",
        params: {
          client_id: process.env.META_APP_ID,
          redirect_uri: `${process.env.NEXTAUTH_URL}/api/auth/callback/meta`,
          scope: "email public_profile instagram_business_profile_get_insights",
          response_type: "code",
        },
      },
      token: "https://graph.instagram.com/v18.0/oauth/access_token",
      userinfo: "https://graph.instagram.com/me?fields=id,name,email",
      profile(profile) {
        return {
          id: profile.id,
          name: profile.name,
          email: profile.email,
          provider: "meta",
        };
      },
      clientId: process.env.META_APP_ID!,
      clientSecret: process.env.META_APP_SECRET!,
    },
  ],
  
  callbacks: {
    async signIn({ user, account, profile }) {
      // Se é sua conta de teste ou email conhecido
      if (user.email === process.env.TESTER_EMAIL) {
        return true; // Sempre permitir
      }
      
      // Novos usuários: criar com tier='trial' por 14 dias
      const existing = await db.user.findUnique({
        where: { email: user.email },
      });
      
      if (!existing) {
        await db.user.create({
          data: {
            email: user.email,
            artist_name: user.name || "Artista",
            user_role: "user",
            app_tier: "trial",
            tier_expires_at: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000),
            created_via: account?.provider || "unknown",
          },
        });
      }
      
      return true;
    },
    
    async session({ session, token }) {
      session.user.id = token.sub; // userID = email
      session.user.tier = token.tier; // Free / Trial / Pro / Super_tester
      session.user.role = token.role; // admin / user / banned
      return session;
    },
  },
};
```

#### **Step 3: Middleware para Proteger Endpoints (Rate Limit)**

**Arquivo**: `web-app/src/middleware.ts` (NOVO)

```typescript
import { getToken } from "next-auth/jwt";
import { NextRequest, NextResponse } from "next/server";

const TIER_LIMITS = {
  free: { monthly_api_calls: 100, storage_mb: 100, max_gigs: 5 },
  trial: { monthly_api_calls: 1000, storage_mb: 500, max_gigs: 50 },
  pro: { monthly_api_calls: 10000, storage_mb: 5000, max_gigs: 999 },
  super_tester: { monthly_api_calls: Infinity, storage_mb: Infinity, max_gigs: Infinity },
};

export async function middleware(request: NextRequest) {
  const token = await getToken({ req: request });
  
  // Block se tier expirou
  if (token?.tier_expires_at && new Date(token.tier_expires_at) < new Date()) {
    if (request.nextUrl.pathname.startsWith("/api/workspace")) {
      return NextResponse.json({ error: "Trial expired. Please upgrade." }, { status: 403 });
    }
  }
  
  // Check API rate limits (usar Redis cache)
  const tierInfo = TIER_LIMITS[token?.tier || "free"];
  const monthKey = `${token?.sub}:${new Date().toISOString().slice(0, 7)}:api_calls`;
  const currentCalls = await redis.get(monthKey) || 0;
  
  if (currentCalls >= tierInfo.monthly_api_calls) {
    return NextResponse.json({ error: "API limit exceeded" }, { status: 429 });
  }
  
  await redis.incr(monthKey);
  
  return NextResponse.next();
}

export const config = {
  matcher: ["/api/workspace", "/api/manager", "/api/spotify", "/api/instagram"],
};
```

#### **Step 4: UI Indicator para Seu Teste (Sem Afetar Testes)**

**Arquivo**: `web-app/src/features/auth/AuthStatus.tsx` (NOVO)

```tsx
export function AuthStatus() {
  const session = useSession();
  const isTester = session.data?.user?.role === "admin" || 
                   session.data?.user?.tier === "super_tester";
  
  return (
    <div className="auth-indicator">
      {isTester && (
        <span className="badge badge-admin">
          🔧 TESTING MODE — This account never expires
        </span>
      )}
      
      <p>{session.data?.user?.email}</p>
      <p>
        Tier: <strong>{session.data?.user?.tier}</strong>
        {session.data?.user?.tier_expires_at && (
          <> • Expires: {new Date(session.data.user.tier_expires_at).toLocaleDateString()}</>
        )}
      </p>
    </div>
  );
}
```

---

## 3. REMOVER MOCKS

### **Objetivo**: Implementar APIs reais para Spotify, Instagram, YouTube

### **A. Spotify Web API (REAL DATA)**

**Arquivo**: `web-app/src/pages/api/spotify/insights.ts`

```typescript
// ANTES: retornava dados mock
// export async function GET(req: NextRequest) {
//   return Response.json({ 
//     topTracks: MOCK_TOP_TRACKS,
//     followers: 1234
//   });
// }

// DEPOIS: chamada real
import { getServerSession } from "next-auth/next";

export async function GET(req: NextRequest) {
  const session = await getServerSession(authOptions);
  if (!session) return Response.json({ error: "Unauthorized" }, { status: 401 });
  
  const spotifyToken = req.cookies.get("psy_spotify_access_token")?.value;
  if (!spotifyToken) {
    return Response.json({ error: "Spotify not connected" }, { status: 403 });
  }
  
  try {
    // 1. Top Tracks
    const topTracksRes = await fetch(
      "https://api.spotify.com/v1/me/top/tracks?limit=5&time_range=short_term",
      {
        headers: {
          Authorization: `Bearer ${spotifyToken}`,
        },
      }
    );
    
    const topTracksData = await topTracksRes.json();
    
    if (!topTracksRes.ok) {
      // Token expirou, refresh
      const newToken = await refreshSpotifyToken(spotifyToken);
      // Retry with new token
    }
    
    // 2. Profile
    const profileRes = await fetch("https://api.spotify.com/v1/me", {
      headers: {
        Authorization: `Bearer ${spotifyToken}`,
      },
    });
    
    const profileData = await profileRes.json();
    
    // 3. Recently Played
    const recentRes = await fetch(
      "https://api.spotify.com/v1/me/player/recently-played?limit=10",
      {
        headers: {
          Authorization: `Bearer ${spotifyToken}`,
        },
      }
    );
    
    const recentData = await recentRes.json();
    
    return Response.json({
      topTracks: topTracksData.items || [],
      profile: {
        followers: profileData.followers.total,
        uri: profileData.uri,
      },
      recentlyPlayed: recentData.items || [],
    });
    
  } catch (error) {
    return Response.json({ error: error.message }, { status: 500 });
  }
}

async function refreshSpotifyToken(token: string) {
  // Usar refresh_token armazenado em Supabase
  const refreshToken = await getSpotifyRefreshToken(session.user.id);
  
  const res = await fetch("https://accounts.spotify.com/api/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      Authorization: `Basic ${Buffer.from(
        `${process.env.SPOTIFY_CLIENT_ID}:${process.env.SPOTIFY_CLIENT_SECRET}`
      ).toString("base64")}`,
    },
    body: new URLSearchParams({
      grant_type: "refresh_token",
      refresh_token: refreshToken,
    }),
  });
  
  const data = await res.json();
  
  // Salvar novo token
  await saveSpotifyAccessToken(session.user.id, data.access_token);
  
  return data.access_token;
}
```

**Implementação**: ~3 horas
- Fetch real de top tracks, playlists, followers
- Refresh token automático
- Caching em Redis (24h TTL)
- Fallback se Spotify indisponível

### **B. Instagram / Meta Graph API (REAL DATA)**

**Arquivo**: `web-app/src/pages/api/instagram/insights.ts`

```typescript
export async function GET(req: NextRequest) {
  const session = await getServerSession(authOptions);
  const instagramToken = req.cookies.get("psy_instagram_access_token")?.value;
  
  if (!instagramToken) {
    return Response.json({ error: "Instagram not connected" }, { status: 403 });
  }
  
  try {
    // 1. Get Instagram Business Account ID
    const igUserRes = await fetch(
      `https://graph.instagram.com/v18.0/me?fields=id,username`,
      {
        headers: {
          Authorization: `Bearer ${instagramToken}`,
        },
      }
    );
    
    const igUser = await igUserRes.json();
    const igBusinessAccountId = igUser.id;
    
    // 2. Insights (followers, impressions, reach)
    const insightsRes = await fetch(
      `https://graph.instagram.com/v18.0/${igBusinessAccountId}/insights?metric=impressions,reach,follower_count,profile_views&period=day`,
      {
        headers: {
          Authorization: `Bearer ${instagramToken}`,
        },
      }
    );
    
    const insights = await insightsRes.json();
    
    // 3. Recent media posts
    const mediaRes = await fetch(
      `https://graph.instagram.com/v18.0/${igBusinessAccountId}?fields=id,media{id,caption,timestamp,like_count,comments_count}`,
      {
        headers: {
          Authorization: `Bearer ${instagramToken}`,
        },
      }
    );
    
    const mediaData = await mediaRes.json();
    
    return Response.json({
      accountId: igBusinessAccountId,
      insights: insights.data || [],
      recentPosts: mediaData.media?.data || [],
    });
    
  } catch (error) {
    return Response.json({ error: error.message }, { status: 500 });
  }
}
```

**Implementação**: ~2 horas
- Insights reais (followers, reach, impressions)
- Recent media com engagement
- Caching em Redis (6h TTL)

### **C. YouTube Data API (REAL DATA)**

**Arquivo**: `web-app/src/pages/api/youtube/insights.ts` (NOVO)

```typescript
import { google } from "googleapis";

export async function GET(req: NextRequest) {
  const session = await getServerSession(authOptions);
  const youtubeToken = session?.youtubeAccessToken; // from session
  
  if (!youtubeToken) {
    return Response.json({ error: "YouTube not connected" }, { status: 403 });
  }
  
  const youtube = google.youtube({
    version: "v3",
    auth: youtubeToken,
  });
  
  try {
    // 1. Get channel info
    const channelRes = await youtube.channels.list({
      part: ["statistics", "snippet"],
      mine: true,
    });
    
    const channel = channelRes.data.items?.[0];
    
    // 2. Get uploads playlist
    const uploadsPlaylistId = channel?.contentDetails?.relatedPlaylists?.uploads;
    
    const videosRes = await youtube.playlistItems.list({
      part: ["snippet", "contentDetails"],
      playlistId: uploadsPlaylistId,
      maxResults: 10,
    });
    
    // 3. Get video stats
    const videoIds = videosRes.data.items?.map((v) => v.contentDetails.videoId) || [];
    const statsRes = await youtube.videos.list({
      part: ["statistics", "snippet"],
      id: videoIds,
    });
    
    return Response.json({
      channelStats: {
        subscribers: channel?.statistics?.subscriberCount || 0,
        views: channel?.statistics?.viewCount || 0,
        videoCount: channel?.statistics?.videoCount || 0,
      },
      videos: statsRes.data.items || [],
    });
    
  } catch (error) {
    return Response.json({ error: error.message }, { status: 500 });
  }
}
```

**Implementação**: ~1.5 horas
- Channel statistics (subscribers, views)
- Recent videos com stats
- Analytics via YouTube Analytics API (opcional)

### **D. Manager IA (OpenAI Real)**

**Arquivo**: `web-app/src/pages/api/manager/route.ts`

```typescript
import OpenAI from "openai";

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

export async function POST(req: NextRequest) {
  const session = await getServerSession(authOptions);
  const { mode, context, message, managerKnowledge, learnedFacts } = await req.json();
  
  // Check tier
  if (session.user.tier === "free") {
    return Response.json({ error: "Manager IA require paid plan" }, { status: 403 });
  }
  
  const systemPrompt = buildManagerPrompt(managerKnowledge, learnedFacts);
  
  try {
    const completion = await openai.chat.completions.create({
      model: "gpt-4-turbo",
      messages: [
        { role: "system", content: systemPrompt },
        ...(await getConversationHistory(session.user.id)),
        { role: "user", content: message },
      ],
      max_tokens: 500,
      temperature: 0.7,
    });
    
    const responseText = completion.choices[0]?.message?.content || "";
    
    // Salvar na história
    await saveManagerMessage(session.user.id, {
      role: "user",
      content: message,
      timestamp: new Date(),
    });
    
    await saveManagerMessage(session.user.id, {
      role: "assistant",
      content: responseText,
      timestamp: new Date(),
    });
    
    return Response.json({ answer: responseText });
    
  } catch (error) {
    console.error("OpenAI error", error);
    return Response.json({ error: error.message }, { status: 500 });
  }
}

function buildManagerPrompt(knowledge, facts) {
  return `Você é Manager IA especializado em orientar artistas de música eletrônica (psytrance, house, techno, etc.).

CONHECIMENTO DO ARTISTA:
${JSON.stringify(knowledge, null, 2)}

CONTEXTO APRENDIDO (histórico):
${facts.join("\n")}

INSTRUÇÕES:
1. Seja específico: Use dados reais (datas, nomes, valores) do contexto.
2. Seja breve: Respostas de 1-2 paragrafos.
3. Recomende ações: Sempre termine com próximo passo recomendado.
4. Linguagem: Português (pt-BR), casual e profissional.

Ajude o artista a tomar decisões sobre gigs, conteúdo, financeiro e booking.`;
}
```

**Implementação**: ~2 horas
- Trocar mock por OpenAI real
- Treinar modelo com dados do artista
- Caching em Redis (per user)

---

## 4. MODELO SaaS

### **Estrutura de Cobrança**

```
┌─────────────────────────────────────────────────────────┐
│                  PsyManager — Pricing                   │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ 🆓 FREE                  │ 💳 PRO (R$ 99/mês)           │
│ • 30 dias trial          │ • Ilimitado - APIs reais      │
│ • 1 usuário              │ • Manager IA (GPT-4)          │
│ • 5 gigs                 │ • Insights reais (Spotify)    │
│ • Sem IA                 │ • Import/Export dados         │
│ • 100 API calls/mês      │ • WhatsApp automático         │
│                          │ • Priority support            │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ 🏢 ENTERPRISE (Sob demanda)                            │
│ • Múltiplas contas                                     │
│ • Integração customizada (Zapier, Make, etc)          │
│ • Relatórios BI (Power BI / Metabase)                 │
│ • SLA 99.9%                                            │
│ • Dedicated support                                    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### **Banco de Dados - Extensões**

```sql
-- Tabela: Planos e Preços
CREATE TABLE psy_plans (
  id SERIAL PRIMARY KEY,
  name VARCHAR(50),           -- 'free', 'pro', 'enterprise'
  price_monthly NUMERIC(10,2), -- R$ 0, 99, custom
  features JSONB,             -- {"max_gigs": 5, "api_calls": 100, "ai": false}
  created_at TIMESTAMPTZ
);

-- Tabela: Subscrições de Usuários
CREATE TABLE psy_subscriptions (
  id SERIAL PRIMARY KEY,
  user_id VARCHAR(255) UNIQUE,  -- ref: psy_users.email
  plan_id INT,                  -- ref: psy_plans.id
  stripe_subscription_id VARCHAR(255),
  status VARCHAR(50),           -- 'active', 'past_due', 'canceled', 'expired'
  current_period_start DATE,
  current_period_end DATE,
  auto_renew BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
);

-- Tabela: Uso de API por usuário
CREATE TABLE psy_usage (
  id SERIAL PRIMARY KEY,
  user_id VARCHAR(255),         -- ref: psy_users.email
  month DATE,                   -- '2026-03-01'
  api_calls INT DEFAULT 0,
  storage_mb NUMERIC(10,2) DEFAULT 0,
  ai_requests INT DEFAULT 0,
  created_at TIMESTAMPTZ
);

-- Tabela: Billing / Invoices
CREATE TABLE psy_invoices (
  id SERIAL PRIMARY KEY,
  user_id VARCHAR(255),         -- ref: psy_users.email
  subscription_id INT,          -- ref: psy_subscriptions.id
  amount_cents INT,             -- R$ 99,00 → 9900 cents
  currency VARCHAR(3) DEFAULT 'BRL',
  status VARCHAR(50),           -- 'draft', 'issued', 'paid', 'overdue'
  due_date DATE,
  issue_date DATE,
  paid_at TIMESTAMPTZ,
  stripe_invoice_id VARCHAR(255),
  pdf_url TEXT,
  created_at TIMESTAMPTZ
);

-- Índices de performance
CREATE INDEX idx_subscriptions_user ON psy_subscriptions(user_id);
CREATE INDEX idx_subscriptions_status ON psy_subscriptions(status);
CREATE INDEX idx_usage_monthly ON psy_usage(user_id, month);
CREATE INDEX idx_invoices_status ON psy_invoices(status, due_date);
```

### **Integração de Pagamento - Stripe + Webhooks**

**Arquivo**: `web-app/src/pages/api/billing/checkout.ts` (NOVO)

```typescript
import Stripe from "stripe";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

export async function POST(req: NextRequest) {
  const session = await getServerSession(authOptions);
  const { planId } = await req.json();
  
  // Obter plano
  const plan = await db.plan.findUnique({ where: { id: planId } });
  if (!plan) return Response.json({ error: "Plan not found" }, { status: 404 });
  
  // Criar Stripe session
  const stripeSession = await stripe.checkout.sessions.create({
    customer_email: session.user.email,
    line_items: [
      {
        price_data: {
          currency: "brl",
          product_data: {
            name: `PsyManager - ${plan.name}`,
            description: `Acesso ao ${plan.name} por 1 mês`,
          },
          unit_amount: Math.round(plan.price_monthly * 100), // Cents
          recurring: {
            interval: "month",
            interval_count: 1,
          },
        },
        quantity: 1,
      },
    ],
    mode: "subscription",
    success_url: `${process.env.NEXTAUTH_URL}/dashboard?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${process.env.NEXTAUTH_URL}/pricing`,
    metadata: {
      user_id: session.user.email,
      plan_id: planId,
    },
  });
  
  return Response.json({ sessionId: stripeSession.id });
}
```

**Arquivo**: `web-app/src/pages/api/billing/webhooks/stripe.ts` (NOVO)

```typescript
import Stripe from "stripe";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);
const endpointSecret = process.env.STRIPE_WEBHOOK_SECRET;

export async function POST(req: NextRequest) {
  const body = await req.text();
  const signature = req.headers.get("stripe-signature");
  
  let event: Stripe.Event;
  
  try {
    event = stripe.webhooks.constructEvent(body, signature, endpointSecret);
  } catch (err) {
    return Response.json({ error: "Webhook signature failed" }, { status: 400 });
  }
  
  switch (event.type) {
    case "customer.subscription.created":
    case "customer.subscription.updated": {
      const subscription = event.data.object as Stripe.Subscription;
      const userId = subscription.metadata.user_id;
      const planId = subscription.metadata.plan_id;
      
      // Atualizar subscription no DB
      await db.subscription.upsert({
        where: { user_id: userId },
        update: {
          status: subscription.status,
          stripe_subscription_id: subscription.id,
          current_period_start: new Date(subscription.current_period_start * 1000),
          current_period_end: new Date(subscription.current_period_end * 1000),
        },
        create: {
          user_id: userId,
          plan_id: planId,
          status: subscription.status,
          stripe_subscription_id: subscription.id,
          current_period_start: new Date(subscription.current_period_start * 1000),
          current_period_end: new Date(subscription.current_period_end * 1000),
        },
      });
      
      // Atualizar user tier
      const plan = await db.plan.findUnique({ where: { id: planId } });
      await db.user.update({
        where: { email: userId },
        data: { app_tier: plan.name },
      });
      
      break;
    }
    
    case "customer.subscription.deleted": {
      const subscription = event.data.object as Stripe.Subscription;
      const userId = subscription.metadata.user_id;
      
      // Downgrade para free
      await db.subscription.update({
        where: { user_id: userId },
        data: {
          status: "canceled",
          auto_renew: false,
        },
      });
      
      await db.user.update({
        where: { email: userId },
        data: { app_tier: "free" },
      });
      
      break;
    }
    
    case "invoice.payment_succeeded": {
      const invoice = event.data.object as Stripe.Invoice;
      
      // Registrar pagamento
      await db.invoice.update({
        where: { stripe_invoice_id: invoice.id },
        data: {
          status: "paid",
          paid_at: new Date(invoice.paid_at * 1000),
        },
      });
      
      // Enviar email
      await sendEmail({
        to: invoice.customer_email,
        subject: "Invoice Paid - PsyManager",
        template: "invoice_paid",
        data: { amount: invoice.amount_paid / 100 },
      });
      
      break;
    }
    
    case "invoice.payment_failed": {
      const invoice = event.data.object as Stripe.Invoice;
      
      // Atualizar status
      await db.invoice.update({
        where: { stripe_invoice_id: invoice.id },
        data: { status: "past_due" },
      });
      
      // Enviar alerta
      await sendEmail({
        to: invoice.customer_email,
        subject: "Payment Failed - Action Required",
        template: "payment_failed",
      });
      
      break;
    }
  }
  
  return Response.json({ received: true });
}
```

### **Portal de Assinatura Stripe**

**Arquivo**: `web-app/src/features/billing/BillingPortal.tsx` (NOVO)

```tsx
"use client";

import { useSession } from "next-auth/react";
import { redirect } from "next/navigation";

export function BillingPortal() {
  const { data: session } = useSession();
  
  const handleManageSubscription = async () => {
    const res = await fetch("/api/billing/customer-portal", {
      method: "POST",
    });
    
    const { portalUrl } = await res.json();
    window.location.href = portalUrl;
  };
  
  return (
    <div className="billing-portal">
      <h2>Seu Plano</h2>
      <p>Plano: <strong>{session?.user?.tier}</strong></p>
      <p>Renovação: <strong>{session?.user?.tier_expires_at}</strong></p>
      
      <button onClick={handleManageSubscription}>
        Gerenciar Assinatura no Stripe
      </button>
    </div>
  );
}
```

**Arquivo**: `web-app/src/pages/api/billing/customer-portal.ts` (NOVO)

```typescript
import Stripe from "stripe";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

export async function POST(req: NextRequest) {
  const session = await getServerSession(authOptions);
  
  const subscription = await db.subscription.findUnique({
    where: { user_id: session.user.email },
  });
  
  if (!subscription?.stripe_subscription_id) {
    return Response.json({ error: "No subscription" }, { status: 404 });
  }
  
  // Get Stripe customer from subscription
  const stripeSubscription = await stripe.subscriptions.retrieve(
    subscription.stripe_subscription_id
  );
  
  const customerId = stripeSubscription.customer as string;
  
  const portalSession = await stripe.billingPortal.sessions.create({
    customer: customerId,
    return_url: `${process.env.NEXTAUTH_URL}/dashboard/billing`,
  });
  
  return Response.json({ portalUrl: portalSession.url });
}
```

---

## 5. LIBERAÇÃO DE APIs

### **A. SPOTIFY** ✅ (Já configurado)

**Status**: Seu app review pode começar **agora**

#### Pré-requisitos:
- ✅ App criado em [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
- ✅ Client ID + Secret gerados
- ✅ Redirect URIs configurados
- ✅ Scopes mínimos aceitos

#### Passos para Production (sem restrição)
1. **Renew app credentials** (manter atualizados)
2. **Testar fluxo completo** com conta de teste
3. **Spotify não requer "review"** — desde que respeite ToS
4. **Limitações conhecidas**:
   - Rate limit: 429 respostas se > 1 req/seg
   - User data não pode ser vendido/compartilhado
   - Never store access tokens > 1 hora (use refresh)

#### ⚠️ **Compliance Checklist**
- [ ] Termos de Serviço Spotify aceitáveis
- [ ] Privacy policy mencionando dados Spotify
- [ ] Botão "Desconectar do Spotify" visível
- [ ] Não vender dados a terceiros
- [ ] Refresh tokens automaticamente

**Timeline**: Já está pronto. Só precisa testar com usuários reais.

---

### **B. META (Instagram)** — Requer Review

**Status**: Deve fazer review antes de lançar para production

#### Pré-requisitos:
- ✅ App criado em [Meta Developers](https://developers.facebook.com/)
- ✅ Domínio verificado
- ✅ Instagram Business Account conectado
- ✅ Commerce Manager (if selling) configurado

#### Tipos de Acesso Meta

| Acesso | O quê | Review? | Duração |
|--------|-------|---------|---------|
| **Desenvolvimento** | Testar com conta própria | ❌ Não | Indefinido |
| **Apps em Teste** | Até 5 testers | ❌ Não | Indefinido |
| **Revisão Seleta** | Acesso expandido, 1-2 semanas | ⚠️ Sim | 30 dias |
| **Produção Pública** | Todos os usuários | ✅ Sim | Aprovação |

#### Passos para Review

**Step 1: Preparar Aplicação**

```
📋 Submit
├── App Name: "PsyManager by [Your Name]"
├── App Description: "Tool for DJ management - bookings, insights, marketing"
├── App Icon: 512x512 PNG
├── Website: https://seu-dominio.com
├── Privacy Policy: https://seu-dominio.com/privacy
├── Terms of Service: https://seu-dominio.com/terms
└── Support Contact: seu-email@seu-dominio.com
```

**Step 2: Solicitar Permissões (Scopes)**

```
Permissões solicitadas:
├── email                              ✅ Básico
├── public_profile                     ✅ Básico
├── instagram_business_profile_get_insights  ⚠️ Requer review
├── pages_read_engagement              ⚠️ Requer review
└── pages_manage_messages              ⚠️ Requer review
```

**Step 3: Criar App Review Request**

```
App Review → Requests → New Request

Permissão: instagram_business_profile_get_insights
├── Description: "Allow users to see their Instagram business insights (followers, reach, impressions) inside PsyManager dashboard."
├── Use Case: 
│   "DJs e artistas conectam suas contas Instagram Business para visualizar 
│    metrics de desempenho em tempo real, ajudando-os a entender comoseu 
│    conteúdo está performando e tomar decisões informadas sobre estratégia de conteúdo."
├── Mockup: [Screenshot mostrando insights.png]
└── Video: [30-60seg demo da feature funcionando]
```

**Step 4: Evidência de Acesso Legítimo**

Meta quer certificar que você:
- ✅ Possui o domínio (DNS verification)
- ✅ Possui a conta Instagram (via OAuth flow)
- ✅ Usa dados apenas para benefício do usuário
- ✅ Não vende dados

**Arquivo**: `INSTAGRAM_BUSINESS_REVIEW.md` (documentação para Meta)

```markdown
# Instagram Business Profile Insights — API Usage

## Caso de Uso (Use Case)
PsyManager é uma plataforma de gerenciamento para artistas de música eletrônica (DJs, produtores).

Um dos recursos é permitir que artistas vejam insights da sua conta Instagram Business 
diretamente no PsyManager, evitando ter que alternar entre múltiplos apps.

### Dados Coletados
- Followers count
- Post reach (últimos 30 dias)
- Impressions
- Engagement rate
- Top posts by engagement

### Como Dados são Usados
1. **Visualização**: Dashboard em tempo real do desempenho de conteúdo
2. **Recommendations**: Manager IA sugerir melhor horário para postar baseado em histórico
3. **Decisões**: Artista decide se precisa mudar estratégia de conteúdo
4. **Armazenamento**: Apenas snapshots diários (não histórico completo)

### O quê NÃO fazemos
- ❌ Vender dados para terceiros
- ❌ Usar dados para targeted advertising fora do Instagram
- ❌ Compartilhar com competitors
- ❌ Armazenar por > 90 dias

### Transparência
- ✅ User pode desconectar a qualquer hora
- ✅ User vê EXATAMENTE quais dados coletamos
- ✅ User pode solicitar deletar dados
- ✅ Privacy policy clara e acessível
```

**Step 5: Timeline de Review**

```
Dia 1: Submit request
Dia 2-3: Meta valida domínio + screenshots
Dia 4-7: Revisão técnica da integração
Dia 5-14: ✅ Aprovado OU ❌ Rejeitado com feedback
         (Se rejeitado, corrige + resubmit)
```

---

### **C. SPOTIFY PREMIUM CHECK** ✅ (Fácil)

**Objetivo**: Alertar user se não é Premium

**Arquivo**: `web-app/src/pages/api/spotify/premium-status.ts` (NOVO)

```typescript
export async function GET(req: NextRequest) {
  const session = await getServerSession(authOptions);
  const spotifyToken = req.cookies.get("psy_spotify_access_token")?.value;
  
  if (!spotifyToken) {
    return Response.json({ isPremium: null }); // Not connected
  }
  
  const res = await fetch("https://api.spotify.com/v1/me", {
    headers: { Authorization: `Bearer ${spotifyToken}` },
  });
  
  const user = await res.json();
  
  return Response.json({
    isPremium: user.product === "premium",
    product: user.product, // 'free' or 'premium'
    externalUrls: user.external_urls,
  });
}
```

**Arquivo**: `web-app/src/features/spotify/SpotifyPremiumAlert.tsx` (NOVO)

```tsx
"use client";

import { useEffect, useState } from "react";

export function SpotifyPremiumAlert() {
  const [isPremium, setIsPremium] = useState<boolean | null>(null);
  
  useEffect(() => {
    fetch("/api/spotify/premium-status")
      .then((r) => r.json())
      .then((data) => setIsPremium(data.isPremium));
  }, []);
  
  if (isPremium === false) {
    return (
      <div className="alert alert-warning">
        <h4>🎵 Spotify Free Detected</h4>
        <p>
          PsyManager funciona melhor com Spotify Premium. Algumas features podem 
          estar limitadas com sua conta Free.
        </p>
        <a href="https://spotify.com/premium" target="_blank">
          Upgrade para Premium →
        </a>
      </div>
    );
  }
  
  return null;
}
```

---

## 6. PUBLICAÇÃO APP STORE

### **Timeline: ~8-10 semanas**

```
Semana 1-2: Preparação
├── TestFlight (opcional, mas recomendado)
├── Screenshots em 6.7", 5.5", 12.9" iPad
├── App Icon (1024x1024)
└── Descrição de loja

Semana 3-4: App Store Connect + Build
├── Criar app entry em App Store Connect
├── Build prod build (release mode)
├── Upload .ipa via Xcode
└── Preencher metadata

Semana 5: Submissão da Review
├── Submit para review
├── Apple pode solicitar mais esclarecimentos
└── ~3-5 dias de espera

Semana 6: Review processo
├── ✅ Aprovado = vai para App Store
├── ⚠️ Needs revision = corrigir + resubmit
└── ❌ Rejected = refazer (raro se bem preparado)

Semana 7: Going live
└── App fica visível em App Store (pode ser searchable no dia 1)
```

### **Pré-requisitos APP STORE**

#### **Certificados e Provisioning**
```bash
# In Xcode
Xcode → Settings → Accounts
├── Add Apple ID (sua conta ou company)
├── Team selection for project
└── Auto-signing enabled ✅

# ou manual (recomendado para production):
# https://developer.apple.com/account/resources/certificates/list
```

#### **App Store Connect Setup**

1. Vá para [App Store Connect](https://appstoreconnect.apple.com)
2. **Agreements, Tax, and Banking** → preenchido? (obrigatório)
3. **Apps** → **My Apps** → **+** → Create App
   ```
   Platform: iOS
   App Name: "PsyManager"
   Bundle ID: "com.seu-empresa.psymanager"
   SKU: "psymanager-2026"
   ```
4. **App Information**
   ```
   App Category: Productivity / Utilities
   Privacy Policy: https://seu-dominio.com/privacy
   ```
5. **Build** → Upload prod build
   ```
   Requirements:
   ├── Minimum iOS: 15.0+
   ├── Supported devices: iPhone 12+
   └── Languages: Portuguese (pt-BR) + English
   ```

#### **Screenshots & Marketing Materials**

Apple quer screenshots de **TODOS esses tamanhos**:

| Device | Requisitado | Tamanho |
|--------|-----------|--------|
| iPhone 6.7" | ✅ Obrigatório | 1284×2778 |
| iPhone 5.5" | ✅ Obrigatório (fallback 6.1") | 1170×2532 |
| iPad | ✅ Obrigatório | 2048×2732 |

**Dica**: Use [AppMockUp generator](https://www.appmocker.io/) para gerar screenshots automaticamente.

#### **App Description & Metadata**

```
Name: PsyManager
Subtitle: Manager IA para Artistas de Música Eletrônica

Description:
PsyManager é seu assistente inteligente para gerenciar:
• 🎵 Bookings: Gerencie suas apresentações e negociações
• 📱 Social Media: Integre Instagram e Spotify, veja insights em tempo real
• 💰 Financeiro: Controle cache-ins e break-even por show
• 🤖 Manager IA: Assistente personalizado que aprende seu estilo e oferece recomendações
• 📅 Logistics: Estime custos de viagem entre cidades

Recursos:
✅ Login com Meta ou Email
✅ Dashboard multi-feature
✅ Síncronização automática com web
✅ Notificações inteligentes
✅ Suporte a múltiplas integrações

Linguagem: Português (pt-BR)
Compatibilidade: iOS 15+ | iPhone 12+
```

#### **Tipo de App**

```
App Type: Productivity

Do you want this version's metadata to be different from the default version?
→ No (unless testing features)

Age Rating:
→ None (unless app tem conteúdo +18)
```

#### **Privacy Policy (OBRIGATÓRIO)**

```
https://seu-dominio.com/privacy

Deve mencionar:
├── Dados coletados: Email, Profile, Photos, Calendar
├── Como são usados: Gerenciamento de conta, IA recommendations
├── Armazenamento: Supabase (criptografado)
├── Compartilhamento: Apenas Spotify/Meta (com consentimento)
├── Retenção: Deletado 30 dias após cancelamento
└── Direito a exportar/deletar dados
```

#### **Checklist Apple Review**

Apple vai verificar:
- ✅ App não faz crash
- ✅ Perguntas de permissões são claras (Camera, Contacts, etc)
- ✅ Se pede permissão de localização: deve justificar **por quê**
- ✅ Se pede permissão de câmera: deve justificar
- ✅ Login funciona corretamente
- ✅ Não vende dados pessoais
- ✅ LGPD/GDPR compliant (se Brasil)

**Arquivo**: `APPLE_SUBMISSION_NOTES.md`

```markdown
# App Submission Notes — PsyManager

## Funcionalidades Comentadas

### Localização (se usar Nominatim geocoding)
- Usamos localização apenas para estimar custos de viagem entre cidades
- O usuário explicitamente entra cidade de origem/destino
- Não coletamos localização GPS em background

### Câmera (se usar para fotos)
- Permitir upload de profile picture
- Opcional — user pode pular

### Contatos (se importar contacts para booking)
- Permitir importação de promoters via contatos
- Informamos ao user que dados serão sincronizados com web

### Calendar (se integrar com EventKit)
- Sincronizar gigs confirmadas para Apple Calendar
- User controla on/off

### Notificações
- Smart alerts: 72h antes de gig, follow-ups pendentes
- User pode desabilitar em settings

## Storage & Privacy
- SQLite local + iCloud backup (opcional)
- Server: Supabase (criptografado em trânsito)
- Dados deletados 30 dias após cancelamento

## Integração Externas
- Spotify OAuth ✅ (apenas read-only)
- Meta/Instagram ✅ (insights apenas)
- Google (YouTube, opcional)
```

#### **Build & Upload**

```bash
# 1. Build para prod
xcodebuild -scheme PsyManager -configuration Release \
  -derivedDataPath build \
  -archivePath build/PsyManager.xcarchive \
  archive

# 2. Exportar .ipa
xcodebuild -exportArchive \
  -archivePath build/PsyManager.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/

# 3. Validar antes de upload
xcrun altool --validate-app -f build/PsyManager.ipa \
  -t iOS \
  --file-type ipa \
  -u seu-apple-id@email.com \
  -p sua-senha-app-specific

# 4. Upload
xcrun altool --upload-app -f build/PsyManager.ipa \
  -t iOS \
  --file-type ipa \
  -u seu-apple-id@email.com \
  -p sua-senha-app-specific
```

**Ou via Xcode (mais fácil)**:
```
Xcode → Product → Archive → Distribute App → Upload
```

---

## 7. CHECKLIST PROFISSIONAL

### **Segurança** 🔐

- [ ] Implementar 2FA (TOTP + SMS backup codes)
- [ ] Rate limiting em endpoints públicos
- [ ] CORS configurado corretamente
- [ ] Refresh tokens expiram em 7 dias
- [ ] Access tokens expiram em 1h
- [ ] Senhas hash com bcrypt (cost: 12+)
- [ ] Audit log completo (quem fez o quê, quando)
- [ ] Encrypt sensitive data at rest (PII)
- [ ] SQL injection proteção (via ORM/parameterized queries)
- [ ] CSRF tokens em formulários
- [ ] CSP headers configurados
- [ ] HTTPS enforced (HSTS)
- [ ] Secrets não no GitHub (env vars apenas)
- [ ] Device fingerprinting para detecção fraude
- [ ] IP whitelist para admin endpoints

### **Performance** ⚡

- [ ] Database indexes otimizados
- [ ] Redis caching (24h TTL para insights)
- [ ] CDN para assets estáticos (Vercel Edge)
- [ ] Image optimization (WebP, lazy loading)
- [ ] Code splitting (dynamic imports)
- [ ] Vite build optimization (tree-shaking)
- [ ] Database query optimization (EXPLAIN ANALYZE)
- [ ] API response caching (ETag headers)
- [ ] Pagination para listas (cursor-based)
- [ ] Background jobs (Bull/Bee-Queue para async tasks)

### **Responsividade** 📱

- [ ] Mobile-first design
- [ ] Responsive breakpoints (320px, 640px, 1024px+)
- [ ] Touch targets ≥ 48px
- [ ] Dark mode support
- [ ] Accessible color contrast (WCAG AA)
- [ ] Keyboard navigation (tab, enter)
- [ ] Screen reader support (role, aria-labels)
- [ ] Form validation (client + server)

### **Testing** ✅

- [ ] Unit tests (Jest/Vitest) — 80%+ coverage
- [ ] Integration tests (API routes)
- [ ] E2E tests (Playwright/Cypress) para critical flows
- [ ] Load testing (k6/JMeter) — simular 100+ users
- [ ] Security scanning (npm audit, OWASP)
- [ ] Visual regression tests (Percy/Chromatic)

### **Compliance** ⚖️

- [ ] Privacy Policy clara e acessível
- [ ] Terms of Service definidos
- [ ] GDPR: direito a exportar dados
- [ ] GDPR: direito a deletar dados ("right to be forgotten")
- [ ] LGPD (Brasil): Aviso sobre retenção de dados
- [ ] LGPD: Consentimento explícito para coleta
- [ ] LGPD: Responder solicitações em 15 dias
- [ ] PCI DSS (se processa cartão): nivel mínimo
- [ ] Cookies notice + consentimento
- [ ] Acessibilidade A11y (WCAG 2.1 AA)

### **DevOps & Infraestrutura** 🏗️

- [ ] CI/CD pipeline (GitHub Actions / GitLab CI)
- [ ] Automated testing em cada PR
- [ ] Automatic deployment (staging → production)
- [ ] Rollback automático se build falha
- [ ] Database backups diários (Supabase point-in-time)
- [ ] Monitoring (Sentry para erros, DataDog/New Relic)
- [ ] Logging estruturado (CloudWatch, LogRocket)
- [ ] Uptime monitoring (Pingdom, UptimeRobot)
- [ ] Load balancing (Vercel edge, múltiplas regiões)
- [ ] DDoS protection (Cloudflare)

### **Operacional** 🎯

- [ ] Runbook (como fazer deploy, troubleshoot, etc)
- [ ] Incident response plan
- [ ] Customer support email setup
- [ ] Knowledge base / FAQ
- [ ] Status page (https://status.seu-dominio.com)
- [ ] Monthly metrics report (MAU, DAU, churn)
- [ ] NPS tracking (feedback)
- [ ] Feature flags (para A/B testing)
- [ ] Analytics integrado (Mixpanel, Amplitude)

### **Documentação** 📚

- [ ] API docs (Swagger/OpenAPI)
- [ ] Architecture Decision Records (ADRs)
- [ ] Setup guide (como rodar localmente)
- [ ] Deployment guide
- [ ] Database schema documented
- [ ] Environment variables documented
- [ ] Troubleshooting guide

---

## 8. SUGESTÕES PARA MELHORAR

### **A. AUMENTAR VALOR (Features que Justificam R$ 99/mês)**

#### **1. Manager IA Avançado** ⭐⭐⭐
```
Atual: ChatGPT genérico com fallback mock
Melhor: 
├── Fine-tuning OpenAI com dados reais de DJs
├── Recommendation engine: "baseado em seu histórico"
├── Decision tree: Que tipo de gig aceitar?
├── Forecasting: Previsão de receita próximos 6 meses
├── Benchmark: Como você se compara com artistas similares?
└── Multi-language coach: Dicas em PT-BR + EN
```

**Implementação**: ~20h (+OpenAI fine-tuning)
**ROI**: Usuários percebem IA "personalizada" vs genérica → maior retention

#### **2. Negociação Automática de Contrato** ⭐⭐
```
Feature: Quando lead confirma interesse, gerar contrato automático
├── Template by evento type (open air, club, festival)
├── Auto-fill: Data, local, fee, carga horária
├── PDF assinável digitalmente
├── Webhook ao Spotify/Instagram (reconfirmar booking)
└── Archive em Google Drive
```

**Integração**: DocuSign API ou SignerHub
**Implementação**: ~15h
**ROI**: Economiza tempo manual + reduz disputas

#### **3. Financial Forecasting** ⭐⭐⭐
```
Dados de entrada:
├── Histórico de gigs (últimos 6 meses)
├── Padrão de leads por temporada
├── Custo fixo (equipment, marketing)
└── Despesas variáveis (viagem, hotel)

Output:
├── Receita projetada (6-12 meses)
├── Break-even point por mês
├── Cenários: pessimista, realista, otimista
├── "Precisa fazer X gigs em março para atingir meta"
└── Alerta: "Você está X% abaixo da projeção"
```

**Integração**: Temporal.io (workflow scheduler) + Prophet (time series)
**Implementação**: ~25h
**ROI**: DJs pagam premium para ter clareza financeira

#### **4. Collaborative Booking (Team Management)** ⭐⭐
```
Feature: Convidar booking agent / manager para gerenciar conta
├── Role-based access (admin, editor, viewer)
├── Audit log: quem fez o quê
├── Shared inbox para mensagens de promoters
├── Approval workflow: agent submete → artist confirma
└── Commission tracking: quanto pagar ao agent
```

**Implementação**: ~20h
**ROI**: Artistasmaiors precisam de team → eles pagam mais

#### **5. Smart Scheduling + Calendar Sync** ⭐⭐
```
Feature: Auto-sugerir melhor data para postar content
├── Input: Histórico de engagement por hora/dia de semana
├── IA analysis: "Seus followers mais ativos às 20h toda quinta"
├── Auto-post: Agendar conteúdo
├── Multi-platform: Postar simultaneamente Instagram, TikTok, YouTube Shorts
└── Performance tracking: "Esse horário teve +35% engagement"
```

**Integração**: Meta Scheduling API, Buffer API
**Implementação**: ~18h
**ROI**: Content creators pagam por eficiência

#### **6. Collaboration with Other Artists (Network)** ⭐
```
Feature: Listar DJs na mesma cidade, sugerir colaborações
├── Directory: Filtrar por gênero, experiência, localização
├── Messaging: Chat direto no app
├── Collaboration Tracking: "Você trabalhou com 7 artistas"
├── Referral Bonuses: "Indique um amigo, ganhe R$ 20 crédito"
└── Spotlight: Featured artists (monetização: "Aparecer featured" = R$ 10/mês)
```

**Implementação**: ~25h
**ROI**: Network effects → sticky product

#### **7. White-Label / Custom Domain** 💎 (Enterprise only)
```
Feature: SaaS para booking agencies
├── Agência cria sub-domínio: api.booking-agency.com
├── Branding customizado (logo, cores)
├── Seus próprios DJs em um workspace
├── Relatórios consolidados
├── Charge seus clientes, você lucra diferença
└── Dedicated support
```

**Implementação**: ~40h (muita customização)
**ROI**: Cada agência = R$ 500-2000/mês

---

### **B. TORNAR PRODUÇÃO-READY**

#### **Monitoramento & Alertes**

```typescript
// Arquivo: web-app/src/lib/monitoring.ts (NOVO)

import * as Sentry from "@sentry/nextjs";
import { getServerSession } from "next-auth/next";

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  tracesSampleRate: 0.1,
  integrations: [
    new Sentry.Integrations.Http({ tracing: true }),
  ],
});

export async function captureException(error: Error, context?: Record<string, any>) {
  const session = await getServerSession();
  
  Sentry.captureException(error, {
    user: {
      email: session?.user?.email,
      tier: session?.user?.tier,
    },
    extra: context,
  });
}

export async function captureEvent(event: string, data?: Record<string, any>) {
  const session = await getServerSession();
  
  Sentry.captureEvent({
    message: event,
    level: "info",
    user: { email: session?.user?.email },
    extra: data,
  });
}

// Uso em uma API route
export async function GET(req: NextRequest) {
  try {
    const data = await expensiveOperation();
    captureEvent("expensive_operation_completed", { duration: Date.now() - start });
    return Response.json(data);
  } catch (error) {
    captureException(error as Error, { route: "/api/workspace" });
    return Response.json({ error: "Internal error" }, { status: 500 });
  }
}
```

#### **Logging Estruturado**

```typescript
// Arquivo: web-app/src/lib/logger.ts (NOVO)

import { createLogger, format, transports } from "winston";

const logger = createLogger({
  level: process.env.LOG_LEVEL || "info",
  format: format.combine(
    format.timestamp(),
    format.json(),
    format((info) => {
      info.service = "psymanager-web";
      return info;
    })()
  ),
  defaultMeta: { service: "psymanager-web" },
  transports: [
    new transports.Console(),
    new transports.File({ filename: "logs/error.log", level: "error" }),
    new transports.File({ filename: "logs/combined.log" }),
  ],
});

export default logger;
```

---

### **C. MELHORAR EXPERIÊNCIA DO USUÁRIO**

#### **Onboarding Guiado**

```tsx
// Arquivo: web-app/src/features/onboarding/OnboardingFlow.tsx (NOVO)

export function OnboardingFlow() {
  const [step, setStep] = useState(0);
  
  const steps = [
    {
      title: "Bem-vindo ao PsyManager! 🎵",
      description: "Seu assistente inteligente para artistas de música eletrônica",
      action: "Próximo",
    },
    {
      title: "Conecte suas plataformas",
      description: "Spotify, Instagram, YouTube",
      action: "Conectar",
    },
    {
      title: "Crie sua primeira apresentação",
      description: "Vamos registrar seu primeiro gig",
      action: "Criar",
    },
    {
      title: "Converse com seu Manager IA",
      description: 'Pergunte "Quando devo postar conteúdo?"',
      action: "Conversar",
    },
  ];
  
  return <OnboardingStep step={steps[step]} onNext={() => setStep(step + 1)} />;
}
```

#### **Empty States Informativos**

```tsx
// Quando um artista não tem nenhum gig:
<EmptyState
  icon="🎪"
  title="Nenhum gig registrado"
  description="Comece adicionando seus próximos shows"
  action={<Button onClick={createGig}>Adicionar Gig</Button>}
/>
```

#### **Tutorial Interativo (Tour.js)**

```typescript
// Arquivo: web-app/src/lib/tour.ts (NOVO)

import Shepherd from "shepherd.js";

export function startProductTour() {
  const tour = new Shepherd.Tour({
    useModalOverlay: true,
    defaultStepOptions: {
      classes: "shepherd-theme-dark",
      scrollTo: true,
    },
  });
  
  tour.addStep({
    id: "dashboard",
    title: "Dashboard",
    text: "Aqui você vê uma visão geral de tudo",
    attachTo: { element: "#dashboard", on: "bottom" },
  });
  
  tour.addStep({
    id: "manager",
    title: "Manager IA",
    text: "Seu assistente inteligente. Pergunte o que quiser!",
    attachTo: { element: "#manager-chat", on: "left" },
  });
  
  tour.start();
}
```

---

### **D. VENDOR LOCK-IN & PORTABILIDADE**

#### **Export Data (GDPR Right)**

```typescript
// Arquivo: web-app/src/pages/api/data/export.ts (NOVO)

export async function GET(req: NextRequest) {
  const session = await getServerSession(authOptions);
  
  const workspace = await db.workspace.findUnique({
    where: { user_id: session.user.email },
  });
  
  // Gerar arquivo ZIP com:
  // ├── workspace.json (tudo)
  // ├── contacts.csv (leads + promoters)
  // ├── gigs.csv (histórico)
  // ├── expenses.csv (financeiro)
  // └── messages.json (histórico de chat)
  
  const zip = new AdmZip();
  zip.addFile("workspace.json", JSON.stringify(workspace, null, 2));
  
  const buffer = zip.toBuffer();
  
  return new Response(buffer, {
    headers: {
      "Content-Disposition": 'attachment; filename="psymanager-export.zip"',
      "Content-Type": "application/zip",
    },
  });
}
```

#### **Data Format Standards**

```json
{
  "version": "1.0.0",
  "exported_at": "2026-04-01T10:00:00Z",
  "format": {
    "gigs": {
      "type": "array",
      "schema": {
        "id": "uuid",
        "title": "string",
        "city": "string",
        "date": "iso8601",
        "fee": "number"
      }
    },
    "leads": { ... }
  }
}
```

**Benefício**: User não fica preso. Se deixar PsyManager, leva seus dados.

---

### **E. ESCALABILIDADE & SLA**

#### **Database Sharding (para 100k+ users)**

```sql
-- Supabase Postgres pode fazer até ~500k concurrent connections
-- Mas recomendamos sharding em 50k-100k users para performance

-- Estratégia: Shard por user_id (hash)
-- Exemplo: user_id % 10 → database_shard_0 até shard_9

CREATE TABLE psy_workspace_shard_0 (
  user_id VARCHAR(255) PRIMARY KEY,
  payload JSONB,
  updated_at TIMESTAMPTZ
);
-- Repetir para shard_1, shard_2, ..., shard_9
```

#### **CDN + Edge Cache**

```
Vercel Edge Network (automaticamente incluído)
├── Global distribution (200+ locations)
├── Automatic caching de assets
├── Compression automática
└── DDoS protection

Cloudflare Rules (optional, adiciona R$ 20/mês)
├── Cache rules: "cache /api/insights 12 hours"
├── Rate limiting: "max 100 requests/minute per IP"
├── WAF rules: block SQLi, XSS, etc
```

#### **Queue para Async Tasks**

```typescript
// Arquivo: web-app/src/lib/queue.ts (NOVO)

import Bull from "bull";

const emailQueue = new Bull("email", {
  redis: {
    host: process.env.REDIS_HOST,
    port: process.env.REDIS_PORT,
  },
});

// Producer
emailQueue.add(
  { to: user.email, template: "welcome" },
  { delay: 5000 } // enviar em 5 secondos
);

// Consumer
emailQueue.process(async (job) => {
  await sendEmail(job.data);
});

// Retry automático
emailQueue.on("failed", (job, err) => {
  if (job.attemptsMade < 3) {
    job.retry(); // retenta até 3 vezes
  }
});
```

**Benefício**: Email/notificações não travam a API

---

### **F. SEGURANÇA EXTRA**

#### **Public Key Infrastructure (PKI)**

```typescript
// Arquivo: web-app/src/lib/encryption.ts (NOVO)

import crypto from "crypto";

// Encrypt sensitive data before storing in DB
export function encryptField(plaintext: string, publicKey: string): string {
  return crypto
    .publicEncrypt(publicKey, Buffer.from(plaintext))
    .toString("base64");
}

export function decryptField(ciphertext: string, privateKey: string): string {
  return crypto
    .privateDecrypt(privateKey, Buffer.from(ciphertext, "base64"))
    .toString("utf-8");
}

// Usage em Supabase
await db.user.update({
  where: { email: user.email },
  data: {
    full_name_encrypted: encryptField(user.full_name, PUBLIC_KEY),
  },
});
```

#### **API Key Rotation**

```typescript
// Arquivo: web-app/src/pages/api/keys/rotate.ts (NOVO)

export async function POST(req: NextRequest) {
  const session = await getServerSession(authOptions);
  
  // Gerar nova key
  const newKey = crypto.randomBytes(32).toString("hex");
  const hash = crypto.createHash("sha256").update(newKey).digest("hex");
  
  // Salvar hash (nunca guardar key em plain text!)
  await db.apiKey.create({
    data: {
      user_id: session.user.email,
      key_hash: hash,
      created_at: new Date(),
      expires_at: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000), // 90 dias
    },
  });
  
  return Response.json({ 
    key: newKey, 
    message: "Guarde em segurança. Não conseguiremos mostrar de novo" 
  });
}
```

---

## RESUMO: ROADMAP PARA PRODUTO VENDÍVEL

### **Phase 1: Este Mês (Conclusão MVP)**
- ✅ Dashboard + Features premium entregues
- ✅ Multi-user Meta login sem quebrar seu teste
- ✅ Remover mocks: Spotify, Instagram real data
- 🔲 Implementar Manager IA real (OpenAI)
- 🔲 Setup cobrança (Stripe)
- 🔲 Security review (2FA, rate limiting)

### **Phase 2: Próximos 60 dias (Production Ready)**
- 🔲 TestFlight com 20 beta testers
- 🔲 App Store submission
- 🔲 Monitoring (Sentry, DataDog)
- 🔲 Financial forecasting feature
- 🔲 GDPR/LGPD compliance full
- 🔲 Documentation + runbook

### **Phase 3: Nos Próximos 6 Meses (Scale & Monetize)**
- 🔲 App Store live
- 🔲 50+ paid subscribers
- 🔲 Feature: White-label para agências
- 🔲 Feature: Team collaboration
- 🔲 Shard database (100k+ users)
- 🔲 Network effects (artist directory, referrals)

### **Investimento de Tempo Estimado**

| Fase | Tarefa | Horas | Custo (R$ 200/h) |
|------|--------|-------|------------------|
| 1 | APIs reais (Spotify, Insta, OpenAI) | 6 | R$ 1.200 |
| 1 | Multi-tenant + Stripe | 15 | R$ 3.000 |
| 1 | Security (2FA, audit log) | 8 | R$ 1.600 |
| 2 | TestFlight + App Store | 16 | R$ 3.200 |
| 2 | Monitoring + Docs | 12 | R$ 2.400 |
| 3 | Advanced features (forecasting, etc) | 40 | R$ 8.000 |
| **Total** | | **97h** | **R$ 19.400** |

**Sua opção: Seguir esse roadmap ou contratar dev freelancer para fases 1-2**

---

**Próximos passos?**
1. Aprovado o roadmap?
2. Quer que comece implementar Phase 1?
3. Qual feature prioritarizar primeiro?

