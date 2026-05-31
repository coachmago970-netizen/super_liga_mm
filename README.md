# Super Liga M&M

Suposicao: MVP com LiveKit Cloud, SMTP via Resend, retencao de `invite_uses.ip_hash` e `invite_uses.user_agent_hash` por 60 dias, e iOS screen share fora do MVP.

Plataforma privada de comunicacao (chat + voz + compartilhamento de tela Android/Desktop) para comunidade fechada.

## Stack

- Flutter (Android, iOS, Windows) com Riverpod e go_router
- Supabase (Auth, Postgres, Realtime, RLS, Storage)
- LiveKit Cloud (voz e tela)
- Backend Node.js + TypeScript + Fastify para token LiveKit e convites

## Status por fase

- M0: concluido (estrutura, env examples, CI base, endpoint `/health`)
- M1: concluido no app (login, cadastro, recuperar senha e logout com Supabase)
- M2: concluido (backend de convite + schema/RLS)
- M3: base funcional (chat com autor, horario, envio, edicao, remocao, realtime e paginacao)
- M4: base funcional (presence para membros online)
- M5: concluido no MVP (token LiveKit + conexao de sala + mute/speaking/sair + multiplas calls por canal de voz)
- M6: concluido no MVP para Android/Desktop (seletor desktop, permissao Android e preview em chamada)
- M7: concluido no MVP base (painel admin com convites, membros, acoes e logs)
- M8: base pronta (rate limit, CORS restrito, helmet, validacao JWT e docs de seguranca)
- M9: base pronta (README + docs principais de setup/deploy/privacidade/checklist)
- Extras UX: perfil e configuracoes funcionais no app

## Estrutura

```text
super_liga_mm/
  apps/flutter_app/
  backend/livekit_token_server/
  supabase/
  docs/
```

## Custo estimado inicial

- Supabase Pro: ~US$25/mes
- LiveKit Cloud: Build gratis no comeco, depois Ship ~US$50/mes (dependendo do uso)
- Backend always-on: ~US$5-7/mes
- SMTP: geralmente tier inicial gratis

Faixa tipica no inicio: ~US$30-85/mes.

## Seguranca implementada

- RLS em todas as tabelas principais
- Validacao de JWT Supabase no backend com JWKS (ou fallback HS256)
- Token LiveKit emitido somente no backend autenticado
- Verificacao de banimento antes de convite e antes de emitir token de voz
- Usuario mutado recebe token de voz em modo escuta (sem permissao de publicar audio/tela)
- Limites de taxa em rotas sensiveis

## Validacao tecnica

- Backend TypeScript: `npm run build` OK
- Backend testes: `npm test` OK (16/16)
- Flutter: nao validado localmente neste ambiente (SDK Flutter indisponivel)

## Como rodar rapido

1. Backend:
   - copiar `backend/livekit_token_server/.env.example` para `.env`
   - instalar dependencias e iniciar em modo dev
2. Flutter:
   - instalar dependencias do app
   - iniciar com `--dart-define` para URL/chaves publicas
3. Supabase:
   - aplicar migrations em `supabase/migrations/`
   - rodar `supabase/seed.sql`

Detalhes completos em [SETUP.md](docs/SETUP.md).

## Publicar online (24h)

1. Subir `backend/livekit_token_server` em um servico always-on (Railway/Render/Fly).
2. Configurar variaveis de ambiente conforme `.env.example`.
3. Validar `GET /health` na URL publica.
4. Atualizar `BACKEND_BASE_URL` no Flutter para a URL HTTPS publica.
5. Regerar APK/AAB e testar de outra rede (4G/Wi-Fi externo).
