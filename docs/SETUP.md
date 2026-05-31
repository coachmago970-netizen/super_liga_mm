# SETUP

## 1) Contas necessarias

- GitHub
- Supabase
- LiveKit Cloud
- Provedor SMTP (Resend/Postmark/SES)
- Hospedagem backend (Render/Railway/Fly)

## 2) Supabase

1. Criar projeto `dev`.
2. Ativar Email + Password no Auth.
3. Configurar SMTP proprio no Auth (obrigatorio para producao).
4. Aplicar migrations:
   - `supabase/migrations/20260530195000_init.sql`
   - `supabase/migrations/20260530213000_message_antispam.sql`
5. Aplicar seed:
   - `supabase/seed.sql`
6. Habilitar Realtime para `messages`.
7. Presence via Realtime channel no app.

## 3) Backend

Pasta: `backend/livekit_token_server`

1. Copiar `.env.example` para `.env`.
2. Preencher:
   - `SUPABASE_URL`
   - `SUPABASE_SECRET_KEY`
   - `SUPABASE_JWKS_URL`
   - `LIVEKIT_API_KEY`
   - `LIVEKIT_API_SECRET`
   - `LIVEKIT_URL`
   - `CORS_ORIGIN`
   - `HASH_PEPPER`
3. Iniciar o servidor em modo local.

Endpoints:

- `GET /health`
- `POST /servers/join` (autenticado; autoentrada no servidor base)
- `POST /channels/list` (autenticado; lista canais do servidor)
- `POST /channels/create` (autenticado + moderator/admin/owner)
- `POST /livekit/token` (autenticado)
  - recebe `serverId` e `channelId` para entrar na call escolhida
  - retorna `channelId`, `channelName`, `room` e `voicePermission` para o app ajustar a UI de voz
- `POST /invites/validate` (publico)
- `POST /invites/use` (autenticado)
- `POST /admin/invites/create` (autenticado + owner/admin)
- `POST /admin/invites/list` (autenticado + owner/admin)
- `POST /admin/invites/deactivate` (autenticado + owner/admin)
- `POST /admin/members/list` (autenticado + moderator/admin/owner)
- `POST /admin/members/set-role` (autenticado + admin/owner)
- `POST /admin/members/ban` / `/unban` (autenticado + admin/owner)
- `POST /admin/members/kick` (autenticado + moderator/admin/owner)
- `POST /admin/members/mute` / `/unmute` (autenticado + moderator/admin/owner)
- `POST /admin/logs/list` (autenticado + moderator/admin/owner)

## 4) Flutter

Pasta: `apps/flutter_app`

Definir as variaveis publicas via `--dart-define`:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`
- `LIVEKIT_URL`
- `BACKEND_BASE_URL`

Rodar no Android e Windows para validar o MVP de screen share (iOS fica para fase posterior).

### Teste no celular (Android local)

1. Deixar o backend rodando no PC em `0.0.0.0:8080`.
2. Descobrir o IP local do PC (ex.: `192.168.100.194`).
3. Garantir celular e PC na mesma rede Wi-Fi.
4. Usar `BACKEND_BASE_URL=http://<IP_DO_PC>:8080` no `--dart-define` do Android (nao usar `localhost` no celular).
5. Executar no celular via USB depuracao:
   - `flutter run -d <android_device_id> --dart-define-from-file=dart_defines.mobile.json`

## 5) Deep links

Configurar:

- Android App Links
- iOS Universal Links
- Scheme: `superligamm://`

Hospedar `.well-known/assetlinks.json` e `.well-known/apple-app-site-association` no dominio final.
Modelos prontos:

- `docs/well-known/assetlinks.json.example`
- `docs/well-known/apple-app-site-association.example`

Formato esperado de convite:

- `https://app.superligamm.com/invite/<CODIGO>`
- `superligamm://invite/<CODIGO>`
- opcional por query: `.../invite?code=<CODIGO>`

## 6) Screen share por plataforma

- Desktop: escolher janela/tela via dialogo.
- Android: declarar foreground service para `mediaProjection` no `AndroidManifest.xml` e pedir permissao de captura (`Helper.requestCapturePermission()`) antes de iniciar.
- iOS: exige Broadcast Upload Extension e App Group (fora do MVP).

Trecho Android (exemplo):

```xml
<service
  android:name="de.julianassmann.flutter_background.IsolateHolderService"
  android:enabled="true"
  android:exported="false"
  android:foregroundServiceType="mediaProjection" />
```
