# DEPLOY

## Ambientes

- `dev`: projeto separado para testes
- `prod`: projeto separado para usuarios reais

Usar Supabase e LiveKit diferentes por ambiente.

## Backend (Render/Railway/Fly)

1. Criar servico always-on.
2. Definir variaveis de ambiente conforme `.env.example`.
3. Build: `npm run build` (ou usar `Dockerfile` pronto em `backend/livekit_token_server/Dockerfile`)
4. Start: `npm start`
5. Conferir `GET /health`.
6. Liberar CORS para os dominos do app (`CORS_ORIGIN`).

### Caminho mais rapido (Railway)

1. Criar projeto no Railway e conectar o repositorio.
2. Selecionar a pasta raiz do servico: `backend/livekit_token_server`.
3. Definir todas as variaveis do `.env.example`:
   - `SUPABASE_URL`
   - `SUPABASE_PUBLISHABLE_KEY`
   - `SUPABASE_SECRET_KEY`
   - `SUPABASE_JWKS_URL` (ou `SUPABASE_JWT_SECRET`)
   - `LIVEKIT_API_KEY`
   - `LIVEKIT_API_SECRET`
   - `LIVEKIT_URL`
   - `APP_BASE_URL`
   - `CORS_ORIGIN`
   - `HASH_PEPPER`
4. Deployar e validar `https://SEU_BACKEND/health`.
5. Atualizar o app para usar `BACKEND_BASE_URL=https://SEU_BACKEND`.

## Supabase

1. Aplicar migrations em `prod`.
2. Aplicar `seed.sql`.
3. Configurar Auth + SMTP + redirect URLs.
4. Validar RLS e policies.

## Flutter

1. Configurar `--dart-define` para ambiente correto.
2. Build Android/iOS/Windows.
3. Validar login, convite, chat, voz e tela (Android/Windows).
4. Em producao, `BACKEND_BASE_URL` deve apontar para URL HTTPS publica do backend.

## Publicacao do app Android

1. Gerar `AAB` (`flutter build appbundle --release ...`).
2. Enviar no Google Play Console (faixa interna primeiro).
3. Testar instalacao pelo link interno.
4. Publicar em producao apos validar auth, chat, voz, calls e convites.

## GitHub no fluxo

- GitHub hospeda o codigo e CI/CD.
- O app nao roda 24h no GitHub sozinho.
- Para 24h, backend precisa estar em provedor de deploy (Railway/Render/Fly/VPS).

## Deep link em producao

1. Configurar dominio oficial.
2. Publicar `assetlinks.json` e `apple-app-site-association`.
3. Testar abertura de convite em Android e iOS.

## Observabilidade

- Uptime monitor no `/health`
- Sentry para Flutter e backend
- Logs estruturados no backend
