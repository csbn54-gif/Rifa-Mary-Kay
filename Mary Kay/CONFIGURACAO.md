RIFA GLAMOUR — VERSÃO COM BANCO ONLINE E CONFERÊNCIA MANUAL
==============================================================

Esta versão está preparada para GitHub Pages + Supabase. Não há prazo de expiração:
os números ficam como AGUARDANDO PAGAMENTO até a organizadora confirmar o Pix ou
liberar manualmente o pedido.

ARQUIVOS
- index.html: site e painel administrativo.
- config.js: URL e chave pública do Supabase (preencher).
- supabase-setup.sql: tabelas, proteção e funções do banco.
- assets/: imagens fornecidas.

CONFIGURAÇÃO INICIAL (necessária antes de publicar)
1. Crie um projeto em https://supabase.com/.
2. Abra SQL Editor no Supabase, cole supabase-setup.sql inteiro e execute.
3. Vá a Project Settings > API (ou Connect) e copie a Project URL e a chave
   publicável/anon. Cole em config.js. NÃO use service_role/secret key no site.
4. Em Authentication > Users, crie seu usuário administrador com e-mail e senha.
5. Copie o UUID desse usuário. No SQL Editor execute, substituindo o UUID:
   insert into public.raffle_admins(user_id)
   values ('COLE-AQUI-O-UUID-DO-USUARIO-ADMIN');
6. Envie index.html, config.js e a pasta assets para seu repositório GitHub.
   Em Settings > Pages, publique a branch/pasta escolhida.
7. Abra o site publicado, clique em Admin, entre com o usuário administrador e
   teste Confirmar Pix recebido e Liberar números usando um pedido de teste.

FLUXO MANUAL
- Cliente seleciona números, informa nome/CPF e envia o pedido.
- O site grava o pedido como pendente e bloqueia os números globalmente.
- O WhatsApp abre com o resumo; cliente envia o comprovante nessa conversa.
- Você confere o crédito no extrato bancário e, no painel Admin, confirma o Pix.
- Se não recebeu ou decidiu cancelar, use Liberar números.
- Não existe expiração automática. Um pedido pendente permanece reservado até
  você tomar uma ação manual.
- A consulta por CPF mostra número(s) e status.

SEGURANÇA / PRIVACIDADE
- Nunca publique a chave service_role ou senhas no GitHub.
- O CPF é dado pessoal. Restrinja o acesso ao repositório se houver arquivos
  internos e não compartilhe exportações do banco.
- A consulta pública por CPF é limitada aos números/status, mas ainda pode ser
  abusada por tentativas repetidas. Para uso público amplo, o ideal é acrescentar
  verificação adicional (ex.: código enviado ao WhatsApp) e limitação de consultas.
- O painel administrativo exige autenticação Supabase e permissão explícita em
  raffle_admins.
- O site não confirma Pix sozinho e não gera comprovante bancário. A confirmação
  é manual e só deve ser feita depois de verificar o dinheiro na conta.
- O “comprovante” desta versão é o registro/status do pedido; comprovante digital
  personalizado pode ser acrescentado depois, após a confirmação manual.

IMPORTANTE
A chave Pix informada foi configurada como 41984767687. Confira se este número está
correto e se está registrado como sua chave Pix. O botão do WhatsApp abre para o
número 5541984767687 (código do Brasil + DDD 41 + telefone informado).
A página mostra oito fotos individuais de produtos além da foto principal da cesta.
Como você mencionou nove itens no total, revise a lista final de prêmios/regulamento
antes de divulgar.
