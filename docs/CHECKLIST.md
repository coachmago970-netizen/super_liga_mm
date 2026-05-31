# CHECKLIST PRE-LANCAMENTO

## Seguranca

- [ ] RLS ativo e revisado em todas as tabelas
- [ ] JWT validado no backend via JWKS
- [ ] Sem segredos no app Flutter
- [ ] CORS restrito (sem `*`)
- [ ] Rate limit ativo nas rotas de token/convite
- [ ] Usuario banido bloqueado em todas as rotas relevantes
- [ ] `.env` fora do repositorio

## Produto

- [ ] Cadastro + confirmacao de e-mail funcionando com SMTP real
- [ ] Convite valida/usa corretamente (inclui expirado/inativo/limite)
- [ ] Chat realtime com limite de 2000 chars
- [ ] Voz funcionando com 2 contas
- [ ] Screen share funcionando no Android e Windows (com permissao de captura validada)

## Operacao

- [ ] `/health` monitorado
- [ ] Logs sem dados sensiveis
- [ ] Backup e plano Supabase de producao confirmados
- [ ] Ambientes `dev` e `prod` separados

## Juridico/LGPD

- [ ] Politica de privacidade publicada
- [ ] Consentimento no cadastro ativo
- [ ] Prazo de retencao para hashes de convite definido
