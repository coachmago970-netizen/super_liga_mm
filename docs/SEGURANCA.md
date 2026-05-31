# SEGURANCA

## Modelo adotado

- O app Flutter conversa com Supabase para auth e dados com RLS.
- O app chama o backend apenas para operacoes com segredo: token LiveKit e convites.
- O backend valida o JWT do Supabase antes de qualquer rota protegida.

## Controles principais

1. RLS em todas as tabelas.
2. JWT validado por JWKS do Supabase no backend.
3. Token de voz emitido apenas no backend e com validade curta.
4. Usuario banido bloqueado em convite e token de voz.
5. Rate limit em rotas sensiveis.
6. CORS restrito por `CORS_ORIGIN`.
7. Headers de seguranca via Helmet.
8. Segredos somente em ambiente de servidor.
9. Anti-spam no banco com trigger: maximo de 10 mensagens por minuto por usuario.

## Politicas RLS

Implementadas em:

- `supabase/migrations/20260530195000_init.sql`

Inclui funcoes `SECURITY DEFINER` para evitar duplicacao de regra por cargo.

## Privacidade tecnica

- IP e User-Agent em `invite_uses` sao armazenados como hash HMAC (nao crus).
- Logs administrativos registram acoes sensiveis.
- Evitar logar token/senha/PII no backend.

## Pendencias recomendadas

- Trocar rate limit em memoria por Redis em producao.
- Adicionar captcha no cadastro.
- Integrar Sentry no Flutter e no backend.
- Revisar checklist antes de liberar para usuarios reais.
