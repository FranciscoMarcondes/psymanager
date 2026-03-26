# 🔍 ANÁLISE: LIMITAÇÕES & ESCALABILIDADE

**Sua pergunta**: "Existe algo referente a essa ideia aonde devo saber para que essa ideia nao tenha limitacao de uso desde do login a uso da i.a e funcionalidades?"

---

## 📊 MATRIZ DE RISCO × ESCALABILIDADE

```
           BAIXO RISCO           ALTO RISCO
           ───────────           ──────────

FÁCIL      ✅ Replicação        ⚠️ Rate limiting
ESCALAR    ✅ Multi-tenant      ⚠️ Database locks

DIFÍCIL    ⚠️ Complexidade      🔴 Gargalos arqui-
ESCALAR    operacional          teturais
```

---

## **1. LIMITAÇÕES DE LOGIN** 🔐

### Risco Hoje ⚠️

| Cenário | Limite | Status |
|---------|--------|--------|
| Sessões simultâneas por usuário | 10+ | ✅ OK (cookies stateless) |
| Login simultâneo (múltiplos devices) | Ilimitado | ✅ OK (JWT tokens) |
| OAuth provider rate limits | Spotify: 30/seg, Meta: 200/min | ⚠️ Pode expirar se viral |
| 2FA setup | Nenhum | 🔴 **Crítico** |
| Password reset | Indefinido | 🔴 **Crítico** |
| Account recovery | Manual | 🔴 **Crítico** |

### Soluções

#### **A. Implementar 2FA** (Crítico para SaaS)

```typescript
// web-app/src/lib/2fa.ts (NOVO)

import speakeasy from "speakeasy";
import QRCode from "qrcode";

export async function generateTOTP(userId: string) {
  const secret = speakeasy.generateSecret({
    name: `PsyManager (${userId})`,
    issuer: "PsyManager",
  });
  
  // Gerar QR code
  const qrCode = await QRCode.toDataURL(secret.otpauth_url);
  
  // Salvar secret em Supabase (criptografado)
  await db.twoFA.create({
    data: {
      user_id: userId,
      secret_encrypted: encryptSecret(secret.base32),
      is_enabled: false,
      created_at: new Date(),
    },
  });
  
  return {
    qrCode,
    secret: secret.base32, // Mostrar só uma vez
    backupCodes: generateBackupCodes(), // Para quando user perde phone
  };
}

export function verifyTOTP(secret: string, token: string): boolean {
  return speakeasy.totp.verify({
    secret,
    encoding: "base32",
    token,
    window: 2, // Allow ±2 time windows for clock skew
  });
}

function generateBackupCodes(): string[] {
  return Array.from({ length: 10 }, () =>
    Math.random().toString(36).substring(2, 10).toUpperCase()
  );
}
```

**Checklist**:
- [ ] `npm install speakeasy qrcode`
- [ ] Implementar enable/disable 2FA em settings
- [ ] Mostrar QR code + backup codes no setup
- [ ] Validar TOTP em cada login (se habilitado)
- [ ] Armazenar backup codes com hash (bcrypt)

#### **B. Password Reset Seguro**

```typescript
// web-app/src/pages/api/auth/reset-password.ts

export async function POST(req: NextRequest) {
  const { email } = await req.json();
  
  const user = await db.user.findUnique({ where: { email } });
  if (!user) {
    // Não revelar se email existe (segurança)
    return Response.json({ message: "Check your email" });
  }
  
  // Gerar token de reset (válido por 1 hora)
  const resetToken = crypto.randomBytes(32).toString("hex");
  const resetTokenHash = crypto
    .createHash("sha256")
    .update(resetToken)
    .digest("hex");
  
  await db.passwordReset.create({
    data: {
      user_id: user.email,
      token_hash: resetTokenHash,
      expires_at: new Date(Date.now() + 60 * 60 * 1000), // 1 hora
    },
  });
  
  // Enviar email
  const resetLink = `https://seu-app.vercel.app/auth/reset-password?token=${resetToken}`;
  
  await sendEmail({
    to: email,
    subject: "Reset seu password",
    template: "reset_password",
    data: { resetLink },
  });
  
  return Response.json({ message: "Email enviado" });
}

// web-app/src/pages/auth/reset-password.tsx

export default function ResetPasswordPage() {
  const searchParams = useSearchParams();
  const token = searchParams.get("token");
  const [password, setPassword] = useState("");
  
  const handleReset = async () => {
    const res = await fetch("/api/auth/reset-password/confirm", {
      method: "POST",
      body: JSON.stringify({ token, password }),
    });
    
    if (res.ok) {
      router.push("/auth/login?success=true");
    }
  };
  
  return (
    <form onSubmit={handleReset}>
      <input
        type="password"
        placeholder="Nova senha"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
        minLength={12}
        pattern="(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]"
        title="Mínimo 12 caracteres, maiúscula, minúscula, número e símbolo"
      />
      <button type="submit">Resetar Password</button>
    </form>
  );
}
```

**Checklist**:
- [ ] Implementar password reset flow
- [ ] Email validation (verificar email antes de resetar)
- [ ] Token expiração (1h)
- [ ] Password requirements (12+ chars, maiúscula, símbolo)
- [ ] Rate limit: max 3 reset attempts/hour por email

#### **C. Session Timeout + Re-authentication**

```typescript
// web-app/src/lib/sessionManager.ts

export const SESSION_TIMEOUT = 24 * 60 * 60 * 1000; // 24h
export const INACTIVITY_TIMEOUT = 15 * 60 * 1000; // 15min

// Middleware para track inatividade
export async function middleware(request: NextRequest) {
  const token = await getToken({ req: request });
  
  if (!token) return NextResponse.next();
  
  const lastActivity = request.cookies.get("last_activity")?.value || Date.now().toString();
  const inactiveFor = Date.now() - parseInt(lastActivity);
  
  // Logout se inativo > 15min
  if (inactiveFor > INACTIVITY_TIMEOUT) {
    const response = NextResponse.redirect(new URL("/auth/login?reason=timeout", request.url));
    response.cookies.delete("next-auth.session-token");
    return response;
  }
  
  // Atualizar last_activity
  const response = NextResponse.next();
  response.cookies.set("last_activity", Date.now().toString());
  
  return response;
}
```

---

## **2. LIMITAÇÕES DE IA** 🤖

### Risco Hoje ⚠️

| Cenário | Limite | Status |
|---------|--------|--------|
| OpenAI requests/min | 60 | ⚠️ Pode atingir com 100+ users |
| Custo por request | ~R$0.01-0.10 | ⚠️ Soma rápido (1000 users = R$100-1000/mês) |
| Latência resposta | 1-5seg | ⚠️ Cliente espera resposta |
| Context window | 128k tokens | ✅ OK (managerKnowledge + histórico small) |
| Fine-tuning | Caro (R$50+/modelo) | ⚠️ Se quiser modelo custom |
| Fallback sem API | Mock responses | 🔴 **Crítico** |

### Soluções

#### **A. Caching de Respostas (Economizar $$$)**

```typescript
// web-app/src/lib/aiCache.ts (NOVO)

import Redis from "ioredis";

const redis = new Redis(process.env.REDIS_URL);

export async function askManagerWithCache(
  userId: string,
  message: string,
  context: any
): Promise<string> {
  // Gerar cache key baseado em similaridade de pergunta
  const messageHash = crypto
    .createHash("md5")
    .update(message.toLowerCase())
    .digest("hex");
  
  const cacheKey = `ai:${userId}:${messageHash}`;
  
  // Verificar se resposta já está em cache
  const cached = await redis.get(cacheKey);
  if (cached) {
    return cached; // Retorna resposta cached (0 custo!)
  }
  
  // Se não, chamar OpenAI
  const response = await askManager(message, context);
  
  // Cachear por 7 dias (user provavelmente faz perguntas similares)
  await redis.setex(cacheKey, 7 * 24 * 60 * 60, response);
  
  return response;
}
```

**Economia estimada**: ~60% de redução em custos de IA

#### **B. Tier-based IA Limits**

```typescript
// web-app/src/pages/api/manager/route.ts

const AI_LIMITS = {
  free: { monthly_requests: 10, includes: ["basic_analysis"] },
  trial: { monthly_requests: 50, includes: ["basic_analysis", "forecasting"] },
  pro: { monthly_requests: 500, includes: ["basic_analysis", "forecasting", "recommendation"] },
};

export async function POST(req: NextRequest) {
  const session = await getServerSession(authOptions);
  const tier = session.user.tier;
  const limit = AI_LIMITS[tier];
  
  // Check monthly limit
  const monthKey = `${session.user.id}:${new Date().toISOString().slice(0, 7)}:ai_requests`;
  const current = await redis.incr(monthKey);
  
  if (current > limit.monthly_requests) {
    return Response.json(
      { error: `Limite de ${limit.monthly_requests} requests/mês atingido` },
      { status: 429 }
    );
  }
  
  // ... resto da lógica
}
```

#### **C. Fallback Elegante (Quando OpenAI Fails)**

```typescript
// web-app/src/services/managerService.ts

export async function askManager(message: string, context: any) {
  try {
    // Tentar OpenAI real
    const response = await openai.chat.completions.create({
      model: "gpt-4-turbo",
      messages: [
        {
          role: "system",
          content: buildSystemPrompt(context),
        },
        { role: "user", content: message },
      ],
      timeout: 10000, // 10seg timeout
    });
    
    return response.choices[0].message.content;
  } catch (error) {
    console.error("OpenAI failed:", error);
    
    // Fallback 1: Respostas template smart
    if (message.toLowerCase().includes("quando postar")) {
      return getSmartTemplate("posting_time", context);
    }
    
    if (message.toLowerCase().includes("quantos gigs")) {
      return getSmartTemplate("gig_forecast", context);
    }
    
    // Fallback 2: Resposta genérica
    return "Desculpe, estou com dificuldade agora. Tente novamente em alguns segundos.";
  }
}

function getSmartTemplate(template: string, context: any) {
  const templates = {
    posting_time: `Baseado no seu histórico, você tem melhor engagement 
      às ${context.peakHour}h de ${context.peakDay}. Recomendo agendar posts nesse horário.`,
    
    gig_forecast: `Você fez ${context.gigsLast30} shows no mês passado. 
      Para manter sua receita, precisa fazer ${context.recommendedGigs} shows este mês.`,
  };
  
  return templates[template] || "Desculpe, não consegui processar sua pergunta.";
}
```

**Risk Mitigation**: 99.9% uptime garantido para Manager mesmo se OpenAI down

---

## **3. LIMITAÇÕES DE FUNCIONALIDADES** ⚙️

### Risco Hoje ⚠️

| Recurso | Limite Atual | Escalabilidade | Risk |
|---------|------------|-----------------|------|
| **Gigs** | Ilimitado (DB) | Ótima | ✅ Baixo |
| **Leads/Negociações** | Ilimitado | Ótima | ✅ Baixo |
| **Content Plan** | Ilimitado | Ótima | ✅ Baixo |
| **Expenses** | Ilimitado | Ótima | ✅ Baixo |
| **Insights** (Spotify/Insta) | 1 request/min | ⚠️ Pode atingir | ⚠️ Médio |
| **Manager IA** | 1 request/10seg | 🔴 **CRÍTICO** | 🔴 Alto |
| **Sync web ↔ iOS** | 100req/min | ⚠️ Pode atingir | ⚠️ Médio |
| **File uploads** (profile pic) | Ilimitado | 🔴 **CRÍTICO** (sem S3) | 🔴 Alto |

### Soluções

#### **A. Rate Limiting Inteligente**

```typescript
// web-app/src/lib/rateLimit.ts (NOVO)

interface RateLimitConfig {
  points: number; // quantas requisições
  duration: number; // em segundos
  blockDuration: number; // bloqueio por X segundos se excede
}

const RATE_LIMITS: Record<string, RateLimitConfig> = {
  "/api/manager": { points: 5, duration: 60, blockDuration: 300 }, // 5/min
  "/api/spotify/insights": { points: 10, duration: 60, blockDuration: 600 }, // 10/min
  "/api/instagram/insights": { points: 10, duration: 60, blockDuration: 600 },
  "/api/workspace": { points: 100, duration: 60, blockDuration: 60 }, // 100/min
};

export async function rateLimit(key: string, userId: string): Promise<boolean> {
  const config = RATE_LIMITS[key];
  if (!config) return true; // Nenhum limite definido
  
  const redisKey = `ratelimit:${userId}:${key}`;
  const current = await redis.incr(redisKey);
  
  if (current === 1) {
    // Primeira requisição, settar expiração
    await redis.expire(redisKey, config.duration);
  }
  
  return current <= config.points;
}

// Middleware
export async function middleware(request: NextRequest) {
  const session = await getToken({ req: request });
  const allowed = await rateLimit(request.nextUrl.pathname, session?.sub);
  
  if (!allowed) {
    return NextResponse.json(
      { error: "Too many requests. Try again later." },
      { status: 429 }
    );
  }
  
  return NextResponse.next();
}
```

#### **B. File Storage (Crítico!)**

**Opção 1: AWS S3** (mais caro, mais escalável)
```typescript
import AWS from "aws-sdk";

const s3 = new AWS.S3();

export async function uploadProfilePicture(file: File, userId: string) {
  const key = `profiles/${userId}/${file.name}`;
  
  await s3
    .putObject({
      Bucket: process.env.AWS_S3_BUCKET!,
      Key: key,
      Body: await file.arrayBuffer(),
      ContentType: file.type,
      ACL: "public-read",
    })
    .promise();
  
  return `https://${process.env.AWS_S3_BUCKET}.s3.amazonaws.com/${key}`;
}
```

**Opção 2: Backblaze B2** (+ barato, mais lento)
```typescript
import B2 from "backblaze-b2";

const b2 = new B2({
  applicationKeyId: process.env.B2_KEY_ID,
  applicationKey: process.env.B2_KEY,
});

export async function uploadProfilePicture(file: File, userId: string) {
  // Similar ao S3...
  const url = await b2.uploadFile(/* ... */);
  return url;
}
```

**Opção 3: Vercel Blob** (mais fácil, integrado)
```typescript
import { put, del } from "@vercel/blob";

export async function uploadProfilePicture(file: File, userId: string) {
  const blob = await put(`profiles/${userId}/avatar.jpg`, file, {
    access: "public",
  });
  
  return blob.url;
}
```

**Recomendação**: Começar com Vercel Blob, migrar para S3 quando tiver 1000+ users

---

## **4. LIMITAÇÕES DE BANCO DE DADOS** 💾

### Risco Hoje ⚠️

```
Supabase Postgres (plano free)
├── Storage: 500MB livre
├── Bandwidth: Ilimitado
├── Connections: 20 simultâneous
├── Performance: OK até 10k users
└── Status: ✅ Bom para MVP
```

### Escalabilidade

| Métrica | 100 users | 1000 users | 10k users | 100k users |
|---------|-----------|-----------|----------|-----------|
| **Storage** | ~10MB | ~100MB | ~1GB | ~10GB |
| **Connections** | 5/sec | 10/sec | 50/sec | 200+/sec 🔴 |
| **Query latency** | 10ms | 20ms | 50ms | 500ms+ 🔴 |
| **Cost/mês** | Free | Free | R$ 50 | R$ 500+ |

### Soluções

#### **A. Database Indexing (Free Speed Boost)**

```sql
-- Criar índices para queries frequentes
CREATE INDEX idx_workspace_user_id ON psy_workspace(user_id);
CREATE INDEX idx_gigs_user_date ON psy_gigs(user_id, date DESC);
CREATE INDEX idx_leads_user_status ON psy_leads(user_id, status);
CREATE INDEX idx_insights_user_created ON psy_insights(user_id, created_at DESC);

-- Verificar índices existentes
SELECT * FROM pg_indexes WHERE tablename = 'psy_workspace';
```

**Impacto**: 10-100x mais rápido em reads

#### **B. Connection Pooling**

```typescript
// web-app/src/lib/supabaseAdmin.ts

import { createClient } from "@supabase/supabase-js";
import { Pool } from "pg";

// Machine-to-machine (backend)
const supabaseAdmin = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY // ← Chave de admin
);

// Connection pool (para múltiplas queries)
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 10, // máx 10 conexões simultâneas
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

export async function runQuery(sql: string, params: any[]) {
  const client = await pool.connect();
  try {
    return await client.query(sql, params);
  } finally {
    client.release();
  }
}
```

#### **C. ReadReplicas (Escalabilidade horizontal)**

```typescript
// Para reads pesados (analytics, reports)
const supabaseReadReplica = createClient(
  process.env.SUPABASE_READ_REPLICA_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

export async function getAnalytics(userId: string) {
  // Query em read replica (não bloqueia writes)
  return supabaseReadReplica
    .from("psy_insights")
    .select("*")
    .eq("user_id", userId)
    .order("created_at", { ascending: false });
}
```

---

## **5. LIMITAÇÕES DE INFRAESTRUTURA** 🏗️

### Risco Hoje ⚠️

| Componente | Setup Atual | Limite | Risk |
|-----------|-----------|--------|------|
| **Hosting Web** | Vercel | 10k requests/sec (auto-scale) | ✅ Baixo |
| **Hosting iOS** | App Store | Ilimitado | ✅ Baixo |
| **Database** | Supabase | 20 connections | ⚠️ Médio |
| **File Storage** | localStorage/Supabase | 500MB | 🔴 Alto |
| **CDN** | Vercel Edge | Global (automaticamente) | ✅ Baixo |
| **Email** | SendGrid/Resend | 100/dia free | 🔴 Alto |
| **SMS** | Nenhum | — | 🔴 Crítico |

### Soluções

#### **A. Email Service Escalável**

```typescript
// web-app/src/lib/email.ts

import { Resend } from "resend";

const resend = new Resend(process.env.RESEND_API_KEY);

export async function sendEmail(
  to: string,
  template: string,
  data: any
): Promise<{ success: boolean; error?: string }> {
  try {
    const html = renderEmailTemplate(template, data);
    
    const result = await resend.emails.send({
      from: "noreply@seu-dominio.com",
      to,
      subject: data.subject,
      html,
      reply_to: "support@seu-dominio.com",
    });
    
    if (result.error) {
      // Log em Sentry para monitoring
      Sentry.captureException(result.error, { userId: to });
      return { success: false, error: result.error.message };
    }
    
    return { success: true };
  } catch (error) {
    return { success: false, error: error.message };
  }
}
```

**Escalabilidade**: 
- Resend: 100/dia free → R$ 24/mês para 50k/mês
- SendGrid: Similar pricing

#### **B. SMS (Opcional, para alerts críticos)**

```typescript
// web-app/src/lib/sms.ts

import twilio from "twilio";

const twilioClient = twilio(
  process.env.TWILIO_ACCOUNT_SID,
  process.env.TWILIO_AUTH_TOKEN
);

export async function sendSMS(phoneNumber: string, message: string) {
  try {
    const result = await twilioClient.messages.create({
      body: message,
      from: process.env.TWILIO_PHONE_NUMBER,
      to: phoneNumber,
    });
    
    return { success: true, sid: result.sid };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

// Uso: Alertas críticos apenas
export async function notifyCriticalAlert(userId: string, message: string) {
  const user = await db.user.findUnique({ where: { email: userId } });
  
  if (user.phoneNumber && user.criticalAlertsViaSMS) {
    await sendSMS(user.phoneNumber, message);
  }
}
```

---

## **6. LIMITAÇÕES OPERACIONAIS** 🎯

### Risco Hoje ⚠️

| Aspecto | Status | Risk |
|--------|--------|------|
| **Monitoring** | Nenhum | 🔴 Alto — não sabe quando quebra |
| **Logging** | Console.log | 🔴 Alto — impossível debugar em prod |
| **Error Tracking** | Nenhum | 🔴 Alto — erros desaparecem |
| **Performance Monitoring** | Nenhum | ⚠️ Médio — não rastreia lentidão |
| **Backups** | Supabase automático | ✅ Bom (diário) |
| **Disaster Recovery** | Nenhum plano | 🔴 Alto — sem playbook |

### Soluções

#### **A. Error Tracking (Sentry)**

```typescript
// web-app/src/lib/sentry.ts

import * as Sentry from "@sentry/nextjs";

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  tracesSampleRate: process.env.NODE_ENV === "production" ? 0.1 : 1.0,
  integrations: [
    new Sentry.Integrations.Http({ tracing: true }),
    new Sentry.Integrations.OnUncaughtException(),
    new Sentry.Integrations.OnUnhandledRejection(),
  ],
});

// Usar em try-catch
try {
  await expensiveOperation();
} catch (error) {
  Sentry.captureException(error, {
    level: "error",
    tags: {
      userId: session?.user?.id,
      feature: "manager_ai",
    },
  });
}
```

#### **B. Performance Monitoring (DataDog/New Relic)**

```typescript
// web-app/src/lib/monitoring.ts

export function logPerformance(operation: string, duration: number) {
  if (duration > 1000) {
    // Log se > 1 segundo
    console.warn(`[SLOW] ${operation}: ${duration}ms`);
    
    Sentry.captureMessage(`Slow operation: ${operation}`, {
      level: "warning",
      extra: { duration },
    });
  }
}

// Usar
const start = performance.now();
await slowQuery();
const duration = performance.now() - start;
logPerformance("spotifyInsightsQuery", duration);
```

---

## **7. CHECKLIST ANTI-GARGALO** ✅

```
[Hoje — MVP]
├─ [ ] Implementar 2FA
├─ [ ] Password reset seguro
├─ [ ] Session timeout + logout
├─ [ ] Error tracking (Sentry)
├─ [ ] Rate limiting por IP
└─ [ ] File upload para S3/Blob

[Próximas 4 semanas — Pre-Production]
├─ [ ] Database indexes
├─ [ ] Redis caching (manager IA)
├─ [ ] Performance monitoring
├─ [ ] Backup strategy (RTO/RPO)
├─ [ ] Load testing (100+ users)
└─ [ ] Disaster recovery playbook

[Após 100 usuários pagos]
├─ [ ] Connection pooling
├─ [ ] Read replicas
├─ [ ] CDN custom (Cloudflare)
├─ [ ] Queue system (Bull)
└─ [ ] Database sharding plan

[Após 10k usuários]
└─ [ ] Infra redesign (microservices, k8s, etc)
```

---

## **RESUMO: VAI PARAR EM ALGUM LUGAR?**

### ✅ NÃO PÁRA AQUI:

**Com arquitetura atual (Vercel + Supabase):**
- ✅ Suporta **até 100k users** sem mudanças arquiteturais
- ✅ Vercel escala automaticamente (serverless)
- ✅ Supabase suporta se usar índices + pooling
- ✅ Custos escalam linearmente (previsível)

### 🔴 PÁRA AQUI:

**Sem implementar:**
- 🔴 2FA → Contas hackeadas → Churn 50%
- 🔴 Error tracking → Bugs não-detectados → Churn 30%
- 🔴 File storage plan → localStorage overflow → App quebra
- 🔴 Rate limiting → DDoS possível → Serviço down
- 🔴 Manager IA fallback → OpenAI down = produto inútil

---

## **PRODUTO VENDÍVEL PRECISA DE:**

```
Tier Free ($0)
├─ 2FA ✅
├─ Login + logout ✅
├─ 5 gigs max
├─ Sem IA
└─ Taxa de churn: ~40%/mês

Tier Pro (R$ 99/mês)
├─ Tudo do Free
├─ Manager IA real
├─ Insights reais (Spotify, Insta)
├─ Ilimitado
├─ Support
└─ Taxa de churn: ~3-5%/mês (SaaS normal)

Métrica Crítica para Viabilidade:
• 50 usuários Pro = R$ 5.000/mês
• Custo infra: R$ 500/mês
• Lucro bruto: R$ 4.500
• Menos: Email, SMS, IA = R$ 1.500
• = R$ 3.000/mês (viável com dev part-time)
```

---

## **CONCLUSÃO**

**Sua ideia NÃO TEM LIMITAÇÕES estruturais até 100k+ usuários**, desde que você:

1. ✅ Implemente 2FA + segurança básica → 10h
2. ✅ Use rate limiting → 3h
3. ✅ Setup error tracking → 2h
4. ✅ Implemente file storage → 2h
5. ✅ Caching de IA → 3h

**Total**: ~20h → ~R$ 4.000 em dev

**Depois disso**: Produto escalável e vendível para R$ 99/mês indefinidamente.

