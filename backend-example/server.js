import 'dotenv/config';
import cors from 'cors';
import express from 'express';

const app = express();
const port = Number(process.env.PORT || 3000);
const baseUrl = process.env.APP_BASE_URL || `http://localhost:${port}`;

app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) => {
  res.json({ ok: true, service: 'psymanager-backend-example' });
});

app.get('/auth/instagram/start', (req, res) => {
  const artist = req.query.artist || '';
  const redirectUri = req.query.redirect_uri;

  if (!redirectUri) {
    return res.status(400).json({ error: 'redirect_uri is required' });
  }

  const callbackUrl = `${baseUrl}/auth/instagram/callback?status=success&handle=${encodeURIComponent(String(artist))}&redirect_uri=${encodeURIComponent(String(redirectUri))}`;
  return res.redirect(callbackUrl);
});

app.get('/auth/instagram/callback', (req, res) => {
  const redirectUri = req.query.redirect_uri;
  const status = req.query.status || 'success';
  const handle = req.query.handle || '';

  if (!redirectUri) {
    return res.status(400).send('redirect_uri missing');
  }

  const finalUrl = `${redirectUri}?status=${encodeURIComponent(String(status))}&handle=${encodeURIComponent(String(handle))}`;
  return res.redirect(finalUrl);
});

app.get('/instagram/insights', (req, res) => {
  const artist = req.query.artist || 'artist';

  const now = new Date();
  const day = 24 * 60 * 60 * 1000;
  const payload = [
    {
      periodLabel: 'Semana -2',
      periodStartISO: new Date(now.getTime() - 21 * day).toISOString(),
      periodEndISO: new Date(now.getTime() - 14 * day).toISOString(),
      followersStart: 1100,
      followersEnd: 1130,
      reach: 5400,
      impressions: 8900,
      profileVisits: 370,
      reelViews: 3000,
      postsPublished: 3,
      artist,
    },
    {
      periodLabel: 'Semana -1',
      periodStartISO: new Date(now.getTime() - 14 * day).toISOString(),
      periodEndISO: new Date(now.getTime() - 7 * day).toISOString(),
      followersStart: 1130,
      followersEnd: 1185,
      reach: 7200,
      impressions: 10800,
      profileVisits: 520,
      reelViews: 4600,
      postsPublished: 4,
      artist,
    },
    {
      periodLabel: 'Semana atual',
      periodStartISO: new Date(now.getTime() - 7 * day).toISOString(),
      periodEndISO: now.toISOString(),
      followersStart: 1185,
      followersEnd: 1248,
      reach: 8600,
      impressions: 13100,
      profileVisits: 610,
      reelViews: 5600,
      postsPublished: 4,
      artist,
    },
  ];

  res.json(payload);
});

app.listen(port, () => {
  console.log(`PsyManager backend example running on ${baseUrl}`);
});
