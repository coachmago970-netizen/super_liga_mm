# GUIA LEIGO

## O que e cada parte

- Flutter: cria o mesmo app para celular e computador com um codigo so.
- Supabase: cuida de usuarios, banco de dados e mensagens em tempo real.
- LiveKit: faz a chamada de voz e o compartilhamento de tela.
- Backend: guarda segredos e libera token temporario da voz com seguranca.
- GitHub: guarda o codigo e ajuda a validar mudancas com testes.

## Contas para criar

1. GitHub
2. Supabase
3. LiveKit Cloud
4. Provedor de e-mail (Resend/Postmark/SES)
5. Hospedagem do backend (Render/Railway/Fly)

## Onde entra cada chave

- Celular/app: apenas chave publica (`SUPABASE_PUBLISHABLE_KEY`) e URLs.
- Servidor backend: chaves secretas (`SUPABASE_SECRET_KEY`, `LIVEKIT_API_SECRET`, `HASH_PEPPER`).

Nunca colocar segredo dentro do app Flutter.

## Como testar localmente

1. Iniciar backend.
2. Iniciar app Flutter.
3. Criar usuario, confirmar e-mail e entrar.
4. Entrar no servidor por convite.
5. Testar chat em tempo real.
6. Testar voz e compartilhamento de tela no Android/Windows.

## Convite por link

- O admin gera um link.
- Quem abre o link primeiro valida o convite.
- Se estiver valido, o usuario entra (ou cria conta e depois entra).

## E-mail (SMTP)

Sem SMTP proprio, a confirmacao de e-mail nao funciona bem em producao.

## iOS e compartilhamento de tela

No iPhone, esse recurso precisa de uma extensao extra nativa. Por isso ficou para depois do MVP.

## Custo mensal resumido

- Supabase Pro: ~US$25/mes
- LiveKit: pode começar gratis e subir conforme uso
- Backend: ~US$5-7/mes
- Total comum no inicio: ~US$30-85/mes
