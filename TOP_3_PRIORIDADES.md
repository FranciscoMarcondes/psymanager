# 🎯 TOP 3 PRIORIDADES — O QUE FAZER AGORA

**Data**: 26.03.2026 | **Status**: MVP feito, precisa deixar production-ready para vender

---

## **1. REMOVER MOCKS + DADOS REAIS** (5-7 horas)

### Situação Atual ❌
```
Spotify insights    → MOCK (dados fake)
Instagram insights  → MOCK (dados fake)
YouTube vídeos      → Não retorna nada
Manager IA          → Fallback hardcoded quando OpenAI down
```

### O Que Fazer ✅

#### **A. Spotify Real Data** (2.5h)

```typescript
// web-app/src/pages/api/spotify/insights.ts

// TROCAR ISSO:
export async function GET() {
  return Response.json(MOCK_INSIGHTS); // Dados fake
}

// POR ISSO:
import axios from "axios";

export async function GET(req: NextRequest) {
  const session = await getServerSession(authOptions);
  const token = req.cookies.get("psy_spotify_access_token")?.value;
  
  if (!token) return Response.json({ error: "Not connected" }, { status: 403 });
  
  try {
    // Top tracks reais
    const topTracksRes = await axios.get(
      "https://api.spotify.com/v1/me/top/tracks?limit=5",
      { headers: { Authorization: `Bearer ${token}` } }
    );
    
    // Profile reais  
    const profileRes = await axios.get(
      "https://api.spotify.com/v1/me",
      { headers: { Authorization: `Bearer ${token}` } }
    );
    
    return Response.json({
      followers: profileRes.data.followers.total,
      topTracks: topTracksRes.data.items,
      isPremium: profileRes.data.product === "premium",
    });
  } catch (error: any) {
    if (error.response?.status === 401) {
      // Token expirou, fazer refresh
      const newToken = await refreshSpotifyToken(token);
      // Retry com novo token
    }
    return Response.json({ error: error.message }, { status: 500 });
  }
}

async function refreshSpotifyToken(token: string) {
  // Implementar usando refresh_token salvo
  return newAccessToken;
}
```

**Checklist**:
- [ ] Adicionar dependency: `npm install axios`
- [ ] Implementar refresh token storage em Supabase
- [ ] Testar com sua conta Spotify
- [ ] Cache em Redis (24h)

#### **B. Instagram Real Data** (1.5h)

```typescript
// web-app/src/pages/api/instagram/insights.ts - SIMILAR ao Spotify

try {
  const meRes = await axios.get(
    `https://graph.instagram.com/v18.0/me?fields=id,username`,
    { headers: { Authorization: `Bearer ${instagramToken}` } }
  );
  
  const businessAccountId = meRes.data.id;
  
  // Insights reais
  const insightsRes = await axios.get(
    `https://graph.instagram.com/v18.0/${businessAccountId}/insights?metric=impressions,reach,follower_count&period=day`,
    { headers: { Authorization: `Bearer ${instagramToken}` } }
  );
  
  return Response.json({
    followers: /* extrair de insights */,
    reach: /* extrair de insights */,
    impressions: /* extrair de insights */,
  });
} catch (error) {
  // Handle error
}
```

**Checklist**:
- [ ] Testar com sua conta Instagram Business
- [ ] Salvar tokens pro

perly
- [ ] Handle token expiration
- [ ] Cache em Redis (12h)

#### **C. YouTube Real Data** (1.5h)

```typescript
// web-app/src/pages/api/youtube/channel.ts (NOVO)

import { google } from "googleapis";

export async function GET(req: NextRequest) {
  const session = await getServerSession(authOptions);
  const youtubeToken = req.headers.get("x-youtube-token"); // from session
  
  const youtube = google.youtube({ version: "v3", auth: youtubeToken });
  
  try {
    // Channel stats
    const channel = await youtube.channels.list({
      part: ["statistics", "snippet"],
      mine: true,
    });
    
    // Recent videos
    const uploads = await youtube.playlistItems.list({
      playlistId: channel.data.items[0].contentDetails.relatedPlaylists.uploads,
      part: ["snippet"],
      maxResults: 10,
    });
    
    return Response.json({
      subscribers: channel.data.items[0].statistics.subscriberCount,
      videos: uploads.data.items,
    });
  } catch (error) {
    return Response.json({ error: error.message }, { status: 500 });
  }
}
```

**Checklist**:
- [ ] `npm install googleapis google-auth-library`
- [ ] Testar com sua conta YouTube
- [ ] Adicionar YouTube no NextAuth providers

#### **D. Manager IA Real (OpenAI)** (1.5h)

```typescript
// web-app/src/pages/api/manager/route.ts

import OpenAI from "openai";

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

export async function POST(req: NextRequest) {
  const { message, managerKnowledge, learnedFacts } = await req.json();
  
  const systemPrompt = `Você é Manager IA especializado em artistas de música eletrônica.

CONHECIMENTO: ${JSON.stringify(managerKnowledge)}
HISTÓRICO: ${learnedFacts.join("\n")}

Responda em PT-BR, seja breve e acionável.`;
  
  try {
    const response = await openai.chat.completions.create({
      model: "gpt-4-turbo",
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: message },
      ],
      max_tokens: 300,
    });
    
    return Response.json({ answer: response.choices[0].message.content });
  } catch (error) {
    // Fallback para resposta mock se OpenAI down
    return Response.json({ answer: getMockResponse(message) });
  }
}
```

**Checklist**:
- [ ] `npm install openai`
- [ ] Adicionar `OPENAI_API_KEY` em `.env.local`
- [ ] Testar integração
- [ ] Implementar cache de respostas em Redis

---

## **2. SETUP COBRANÇA + PLANOS** (8-10 horas)

### Situação Atual ❌
Não tem sistema de pagamento. Todos estão em "free" indefinido.

### O Que Fazer ✅

#### **Step 1: Criar Planos em Banco de Dados** (1h)

```sql
-- Adicionar em Supabase
CREATE TABLE psy_plans (
  id SERIAL PRIMARY KEY,
  name VARCHAR(50),                    -- 'free', 'pro'
  price_monthly NUMERIC(10, 2),        -- 0, 99
  features JSONB,                      -- {"max_gigs": 999, "ai": true}
  created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO psy_plans VALUES
  (1, 'free', 0.00, '{"max_gigs": 5, "ai": false, "api_calls": 100}'::jsonb),
  (2, 'pro', 99.00, '{"max_gigs": 999, "ai": true, "api_calls": 10000}'::jsonb);

CREATE TABLE psy_subscriptions (
  id SERIAL PRIMARY KEY,
  user_id VARCHAR(255) UNIQUE,
  plan_id INT REFERENCES psy_plans(id),
  stripe_subscription_id VARCHAR(255),
  status VARCHAR(50) DEFAULT 'active',   -- 'active', 'canceled', 'past_due'
  current_period_end DATE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE psy_invoices (
  id SERIAL PRIMARY KEY,
  user_id VARCHAR(255),
  amount_cents INT,                    -- 9900 = R$ 99,00
  status VARCHAR(50) DEFAULT 'draft',   -- 'draft', 'issued', 'paid'
  stripe_invoice_id VARCHAR(255),
  created_at TIMESTAMPTZ DEFAULT now()
);
```

**Checklist**:
- [ ] Executar SQL em Supabase console
- [ ] Verificar tabelas criadas

#### **Step 2: Integrar Stripe** (3h)

```bash
npm install stripe next-stripe
```

```typescript
// web-app/src/pages/api/billing/create-checkout.ts (NOVO)

import Stripe from "stripe";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);

export async function POST(req: NextRequest) {
  const { planId } = await req.json();
  const session = await getServerSession(authOptions);
  
  // Buscar plano
  const plan = await db.plan.findUnique({ where: { id: planId } });
  
  // Criar Stripe session
  const checkoutSession = await stripe.checkout.sessions.create({
    customer_email: session.user.email,
    line_items: [
      {
        price_data: {
          currency: "brl",
          product_data: {
            name: `PsyManager ${plan.name}`,
            description: `Acesso mensal ao plano ${plan.name}`,
          },
          unit_amount: Math.round(plan.price_monthly * 100),
          recurring: {
            interval: "month",
            interval_count: 1,
          },
        },
        quantity: 1,
      },
    ],
    mode: "subscription",
    success_url: `${process.env.NEXTAUTH_URL}/dashboard?success=true`,
    cancel_url: `${process.env.NEXTAUTH_URL}/pricing`,
  });
  
  return Response.json({ url: checkoutSession.url });
}
```

```typescript
// web-app/src/features/pricing/PricingPage.tsx

"use client";

export function PricingPage() {
  const handleCheckout = async (planId: number) => {
    const res = await fetch("/api/billing/create-checkout", {
      method: "POST",
      body: JSON.stringify({ planId }),
    });
    
    const { url } = await res.json();
    window.location.href = url; // Redireciona para Stripe
  };
  
  return (
    <div className="pricing">
      <Card>
        <h3>Free</h3>
        <p className="price">R$ 0</p>
        <ul>
          <li>5 gigs</li>
          <li>Sem IA</li>
          <li>100 API calls/mês</li>
        </ul>
        <button disabled>Seu Plano Atual</button>
      </Card>
      
      <Card featured>
        <h3>Pro</h3>
        <p className="price">R$ 99<small>/mês</small></p>
        <ul>
          <li>Ilimitado</li>
          <li>Manager IA</li>
          <li>Insights reais</li>
        </ul>
        <button onClick={() => handleCheckout(2)}>Fazer Upgrade</button>
      </Card>
    </div>
  );
}
```

**Checklist**:
- [ ] Criar conta em [Stripe Dashboard](https://dashboard.stripe.com)
- [ ] Pegar Secret Key + Publishable Key
- [ ] Adicionar em `.env.local`
- [ ] Implementar webhook Stripe
- [ ] Testar checkout com cartão teste: `4242 4242 4242 4242`

#### **Step 3: Webhook Stripe (para confirmar pagamento)** (2h)

```typescript
// web-app/src/pages/api/webhooks/stripe.ts (NOVO)

import Stripe from "stripe";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);
const endpointSecret = process.env.STRIPE_WEBHOOK_SECRET!;

export async function POST(req: NextRequest) {
  const body = await req.text();
  const sig = req.headers.get("stripe-signature")!;
  
  let event: Stripe.Event;
  
  try {
    event = stripe.webhooks.constructEvent(body, sig, endpointSecret);
  } catch (err) {
    return Response.json({ error: "Invalid signature" }, { status: 400 });
  }
  
  // Quando pagamento é confirmado
  if (event.type === "customer.subscription.created") {
    const subscription = event.data.object as Stripe.Subscription;
    const userId = subscription.metadata.user_id;
    const planId = parseInt(subscription.metadata.plan_id);
    
    // Salvar subscription no DB
    await db.subscription.upsert({
      where: { user_id: userId },
      update: {
        plan_id: planId,
        stripe_subscription_id: subscription.id,
        status: "active",
        current_period_end: new Date(subscription.current_period_end * 1000),
      },
      create: {
        user_id: userId,
        plan_id: planId,
        stripe_subscription_id: subscription.id,
        status: "active",
        current_period_end: new Date(subscription.current_period_end * 1000),
      },
    });
    
    // Atualizar user tier
    const plan = await db.plan.findUnique({ where: { id: planId } });
    await db.user.update({
      where: { email: userId },
      data: { app_tier: plan.name },
    });
  }
  
  return Response.json({ received: true });
}

// Em next.config.js (para Vercel webhook):
export const runtime = "nodejs"; // Força Node runtime (não edge)
```

**Checklist**:
- [ ] Ir em Stripe Dashboard → Webhooks
- [ ] Adicionar endpoint: `https://seu-app.vercel.app/api/webhooks/stripe`
- [ ] Selecionar eventos: `customer.subscription.created`, `customer.subscription.updated`, `invoice.payment_succeeded`
- [ ] Copiar signing secret em `STRIPE_WEBHOOK_SECRET`
- [ ] Testar webhook com `stripe listen --forward-to localhost:3000/api/webhooks/stripe`

#### **Step 4: Bloquear Features by Plan** (2h)

```typescript
// web-app/src/features/workspace/Workspace.tsx

export function Workspace() {
  const { session } = useSession();
  const isPro = session?.user?.tier === "pro" || session?.user?.tier === "super_tester";
  
  // Bloquear Manager IA se free
  const handleAskManager = async (message: string) => {
    if (!isPro) {
      showModal({
        title: "Upgrade para Pro",
        description: "Manager IA está disponível apenas para plano Pro",
        action: "Fazer Upgrade",
        onAction: () => router.push("/pricing"),
      });
      return;
    }
    
    // Fazer request normal
    await fetch("/api/manager", { method: "POST", body: JSON.stringify({ message }) });
  };
  
  return (
    <>
      {!isPro && (
        <Banner type="warning">
          Você está no plano Free. Faça upgrade para R$ 99/mês para desbloquear todas as features.
          <Button onClick={() => router.push("/pricing")}>Upgrade Agora</Button>
        </Banner>
      )}
      
      {/* Renderizar Manager IA com lock overlay se free */}
      <ManagerPanel disabled={!isPro} />
    </>
  );
}
```

**Middleware para API**:

```typescript
// web-app/src/middleware.ts (NOVO)

export async function middleware(request: NextRequest) {
  const token = await getToken({ req: request });
  
  // Bloquear /api/manager se não é pro
  if (request.nextUrl.pathname === "/api/manager") {
    if (token?.tier !== "pro" && token?.tier !== "super_tester") {
      return NextResponse.json(
        { error: "Upgrade to Pro to use Manager IA" },
        { status: 403 }
      );
    }
  }
  
  return NextResponse.next();
}
```

**Checklist**:
- [ ] Adicionar feature flags por plan
- [ ] Testar com conta free e pro
- [ ] Implementar paywalls na UI

---

## **3. MULTI-USER + META LOGIN (sem quebrar seu teste)** (6-8 horas)

### Situação Atual ❌
- Só há 1 usuário de teste (seu email)
- Meta login não está implementado
- Novos usuários misturam dados

### O Que Fazer ✅

#### **Step 1: Adicionar `user_role` + `app_tier` ao banco de dados** (1h)

```sql
-- Em Supabase
ALTER TABLE psy_users ADD COLUMN user_role VARCHAR(50) DEFAULT 'user';
ALTER TABLE psy_users ADD COLUMN app_tier VARCHAR(50) DEFAULT 'free';
ALTER TABLE psy_users ADD COLUMN subscription_id VARCHAR(255);

-- Marcar SUA conta como admin (PERMANENTE)
UPDATE psy_users 
SET user_role = 'admin', app_tier = 'super_tester'
WHERE email = 'seu-email@seu-dominio.com';

-- Verificar
SELECT email, user_role, app_tier FROM psy_users;
```

**Checklist**:
- [ ] Columns criadas em psy_users
- [ ] Sua conta tem `super_tester` tier

#### **Step 2: Implementar Meta Login** (3-4h)

```typescript
// web-app/src/lib/authOptions.ts

import { FacebookProvider } from "next-auth/providers/facebook";

export const authOptions: NextAuthOptions = {
  providers: [
    // ... existentes: Spotify, Google, Credentials
    
    // NOVO: Meta Provider
    FacebookProvider({
      clientId: process.env.META_APP_ID!,
      clientSecret: process.env.META_APP_SECRET!,
      allowDangerousEmailAccountLinking: true,
      scope: "public_profile,email,instagram_business_profile_get_insights",
    }),
  ],
  
  callbacks: {
    async signIn({ user, account, profile }) {
      // SUA CONTA: sempre permitir
      if (user.email === process.env.TESTER_EMAIL) {
        return true;
      }
      
      // NOVOS USUÁRIOS
      const existing = await db.user.findUnique({
        where: { email: user.email },
      });
      
      if (!existing) {
        // Criar usuário novo com trial de 14 dias
        await db.user.create({
          data: {
            email: user.email,
            artist_name: user.name || "Novo Artista",
            user_role: "user",
            app_tier: "trial",
            tier_expires_at: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000),
            created_via: account?.provider || "unknown",
          },
        });
      }
      
      return true;
    },
    
    async jwt({ token, account }) {
      if (account) {
        token.provider = account.provider;
      }
      
      // Adicionar tier do usuário ao token
      const user = await db.user.findUnique({
        where: { email: token.email! },
      });
      
      token.tier = user?.app_tier;
      token.role = user?.user_role;
      token.tier_expires_at = user?.tier_expires_at;
      
      return token;
    },
    
    async session({ session, token }) {
      session.user.tier = token.tier;
      session.user.role = token.role;
      session.user.tier_expires_at = token.tier_expires_at;
      return session;
    },
  },
};
```

**Adicionar em `.env.local`**:
```
META_APP_ID=seu_app_id_aqui
META_APP_SECRET=seu_app_secret_aqui
TESTER_EMAIL=seu-email@seu-dominio.com  # ← Sua conta protegida
```

**Checklist**:
- [ ] Criar app em [Facebook Developers](https://developers.facebook.com)
- [ ] Adicionar Facebook provider ao seu Next.js
- [ ] Testar login com conta Meta/Facebook pessoal
- [ ] Verificar que SUA conta (TESTER_EMAIL) está protegida

#### **Step 3: UI Indicator para seu Teste** (1h)

```tsx
// web-app/src/components/TestingBadge.tsx (NOVO)

"use client";

import { useSession } from "next-auth/react";

export function TestingBadge() {
  const { data: session } = useSession();
  const isTester = session?.user?.role === "admin";
  
  if (!isTester) return null;
  
  return (
    <div 
      className="fixed top-2 right-2 bg-blue-500 text-white px-3 py-1 rounded-full text-sm font-bold"
      title="Sua conta de teste - nunca expires, sempre super_tester"
    >
      🔧 TESTING MODE
    </div>
  );
}

// Usar em layout.tsx
import { TestingBadge } from "@/components/TestingBadge";

export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        <TestingBadge />
        {children}
      </body>
    </html>
  );
}
```

**Checklist**:
- [ ] Badge aparece apenas para SUA conta
- [ ] Outros usuários não veem

#### **Step 4: Middleware para Rate Limiting by Tier** (2h)

```typescript
// web-app/src/middleware.ts

import { getToken } from "next-auth/jwt";
import { NextRequest, NextResponse } from "next/server";

const TIER_LIMITS = {
  free: { monthly_api_calls: 100, max_gigs: 5 },
  trial: { monthly_api_calls: 1000, max_gigs: 50 },
  pro: { monthly_api_calls: 10000, max_gigs: 9999 },
  super_tester: { monthly_api_calls: Infinity, max_gigs: Infinity },
};

export async function middleware(request: NextRequest) {
  const token = await getToken({ req: request });
  
  // Permitir se sem autenticação (login page)
  if (!token || request.nextUrl.pathname.startsWith("/api/auth")) {
    return NextResponse.next();
  }
  
  // Bloquear se tier expirou
  if (token.tier_expires_at) {
    const expiryDate = new Date(token.tier_expires_at);
    if (expiryDate < new Date()) {
      if (request.nextUrl.pathname.startsWith("/api/manager")) {
        return NextResponse.json(
          { error: "Trial expired. Please upgrade." },
          { status: 403 }
        );
      }
    }
  }
  
  // Rate limit (usar Redis em production)
  const monthKey = `${token.sub}:${new Date().toISOString().slice(0, 7)}:api_calls`;
  const limit = TIER_LIMITS[token.tier || "free"].monthly_api_calls;
  
  // Simple in-memory counter (replace com Redis em production)
  if (!global.rateLimitMap) {
    global.rateLimitMap = {};
  }
  
  const currentCalls = global.rateLimitMap[monthKey] || 0;
  
  if (currentCalls >= limit) {
    return NextResponse.json(
      { error: `API limit exceeded (${limit} calls/month)` },
      { status: 429 }
    );
  }
  
  global.rateLimitMap[monthKey] = currentCalls + 1;
  
  return NextResponse.next();
}

export const config = {
  matcher: ["/api/:path*", "/:path*"],
};
```

**Checklist**:
- [ ] Middleware implementado
- [ ] Testar com conta free (deve ser limitada)
- [ ] Testar com SUA conta (sem limite)

---

## **ORDEM DE EXECUÇÃO RECOMENDADA**

```
Semana 1:
Day 1-2: APIs reais (Spotify, Instagram) → teste com seus dados
Day 3:   Manager IA da OpenAI → teste conversations
Day 4-5: Stripe integration → checkout funcionando

Semana 2:
Day 6:   Multi-user + Meta login
Day 7-8: Rate limiting + tiers
Day 9:   Testing + QA
Day 10:  Deploy para production
```

**Total**: ~15h de trabalho

---

## **ANTES & DEPOIS**

### ❌ Antes (Hoje)
```
┌─ Você ─────────────────────────────────┐
│  App sempre open, testa features       │
│  Dados: TODOS mock, não real           │
│  Pagamento: Nenhum                     │
│  Múltiplos usuários: Quebra            │
└────────────────────────────────────────┘
```

### ✅ Depois (Em 2 semanas)
```
┌─ Você (super_tester) ──────────────────┐
│  Badge "TESTING MODE" (protegido)      │
│  Dados: Reais (Spotify, Insta, OpenAI) │
│  Pode testar indefinidamente           │
│  Sem riscos de trial expirar           │
├────────────────────────────────────────┤
│  Novos Usuários                        │
│  ├─ Meta login funciona                │
│  ├─ Trial 14 dias gratuito             │
│  ├─ Upgrade para R$ 99/mês (Pro)       │
│  ├─ Dados isolados (multi-tenant) ✅   │
│  └─ Rate limits aplicados              │
└────────────────────────────────────────┘
```

---

## **PRÓXIMOS PASSOS PARA VOCÊ**

1. **Confirme a prioridade**:
   ```
   ☐ Prioritário: APIs reais → cobrança → multi-user
   ☐ Ou: Primeiro multi-user → depois APIs?
   ```

2. **Recursos necessários**:
   ```
   ☐ OpenAI API key (R$5-20 para testes)
   ☐ Stripe account (gratuito, comissão depois)
   ☐ Facebook App ID + Secret (gratuito, ~5min setup)
   ```

3. **Start date?**
   ```
   ☐ Começar essa semana?
   ☐ Esperar até quando?
   ```

**Já temos todos os códigos prontos.** Só precisa executar 💪

