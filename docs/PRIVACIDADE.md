# PRIVACIDADE (LGPD)

## Dados coletados

- E-mail e senha (login)
- Nome de exibicao e avatar (identificacao no app)
- Mensagens de chat
- Logs administrativos (acoes sensiveis)
- Hash de IP e User-Agent em uso de convite (anti-abuso)

## Finalidade

- Permitir autenticacao e acesso ao servidor privado
- Entregar comunicacao em tempo real (chat e voz)
- Proteger a plataforma contra abuso/fraude

## Base legal (LGPD)

- Consentimento no cadastro
- Legitimo interesse para seguranca, prevencao de abuso e operacao

## Direitos do titular

Titular pode solicitar:

- Acesso aos dados
- Correcao
- Exclusao
- Portabilidade

Contato do encarregado: `privacidade@superligamm.com` (placeholder).

## Exclusao de conta

Prever fluxo "Excluir minha conta" no app:

- Apagar ou anonimizar dados pessoais
- Preservar apenas o minimo necessario para obrigacoes legais e seguranca

## Retencao

- `invite_uses.ip_hash` e `invite_uses.user_agent_hash`: 60 dias (ajustavel para 30-90)
- Logs administrativos: conforme politica interna de seguranca

## Protecao

- HTTPS obrigatorio
- RLS no banco
- Segredos fora do cliente
- Logs sem exposicao de token/senha

## Consentimento no cadastro

Cadastro deve ter checkbox obrigatorio para Termos e Privacidade com link visivel.
