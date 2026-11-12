# Brechó: arquitetura, regras e passagem de bastão

Documento escrito em 11 de novembro de 2026, ao fim da "Atualização 8" do código. Serve para qualquer pessoa ou IA continuar o projeto sem depender do histórico da conversa. Está em português porque o usuário trabalha em português.

Arquivos do projeto: `index.html` (todo o site), `schema.sql` e `migracao-1` a `migracao-5` (banco de dados), `LEIA-ME.md` (passo a passo de instalação e de cada atualização) e este arquivo.

---

## 0. Para a próxima IA: leia isto primeiro

**Prompt de continuidade (cole no início da nova conversa, junto com os arquivos):**

> Você vai continuar o desenvolvimento de um site de vitrine com reserva e Pix para brechós (peças únicas). Leia o arquivo ARQUITETURA-E-HANDOFF.md inteiro antes de responder. O usuário cuida de negócio, experiência e valor do produto; você cuida de programação e infraestrutura. Ele não programa: aplica mudanças pelo editor web do GitHub e pelo painel do Supabase, e precisa de instruções passo a passo em português, com nomes exatos de botões. O orçamento é zero, a operação é anônima e 100% online. Nunca declare que algo funciona sem avisar o que foi de fato testado: o código nunca foi executado contra um projeto Supabase real por quem o escreveu. Antes de entregar qualquer arquivo, rode a verificação de sintaxe e a simulação descritas no Apêndice A.

**Regras de trabalho que funcionaram até aqui**

1. Seja honesto sobre incerteza: informe o que foi verificado (sintaxe, simulação com dados falsos) e o que não foi (banco real, e-mail, pagamento).
2. Faça as mudanças em lotes. Cada atualização do `index.html` obriga o usuário a colar de novo as chaves (ver seção 14, melhoria nº 1).
3. Toda mudança de dados exige um arquivo SQL novo, numerado, que o usuário roda no SQL Editor do Supabase.
4. Entregue com um passo a passo curto e diga quais campos o usuário precisa preencher depois.
5. Não prometa recursos que dependam de custo (gateway de pagamento, API dos Correios, servidor próprio) sem avisar o custo e a exigência de CNPJ.

---

## 1. Contexto de negócio

### 1.1 Pessoas e restrições

- **Usuário:** descreve-se como estudante. Responsável por requisitos de negócio, experiência do cliente e valor do produto. Não precisa que o negócio seja voltado a estudantes; ser estudante só significa que **não há orçamento para investir**.
- **IA:** responsável por programação, infraestrutura, segurança e estimativas técnicas.
- **Restrições assumidas:** negócio 100% online (site ou app), sem estoque ou ponto físico, **operação anônima** (marca sem rosto), **sem credencial ou cargo profissional**, custo inicial zero (planos gratuitos), sem anúncio pago.
- **Formalização:** para cobrar mensalidade dos brechós será preciso CPF ou CNPJ e um serviço de cobrança. A legislação de comércio eletrônico pede identificação do fornecedor no site, e a LGPD pede identificar o responsável pelos dados. Nada disso foi feito ainda.
- **Perfil técnico do usuário:** opera pelo GitHub (interface web) e pelo painel do Supabase. Não roda código na própria máquina.

### 1.2 Como se chegou ao produto

1. Começou com a ideia de uma "fábrica de micro-SaaS" para pequenos negócios brasileiros.
2. O usuário restringiu: nada físico, tudo online, anônimo, sem cargo, sem orçamento.
3. Foram avaliadas dezenas de ideias. As finalistas foram duas: **A) catálogo e pedidos para brechós** e **B) alertas de licitações para pequenos fornecedores**.
4. Foram cortadas, após pesquisa de concorrência: relatórios para gestores de tráfego (Reportei e outros dominam) e quadro de vagas de nicho (Remotar e ciclo "ovo e galinha").
5. A pesquisa mostrou que licitações é um mercado concorrido, com plano grátis (Effecti) e preço de entrada baixo (Alerta Licitação). **Decisão: seguir com brechós.** Licitações ficou como segunda aposta, só com foco em iniciantes.
6. Foi construído, em etapas, o site do brechó descrito neste documento.

### 1.3 Modelo de negócio

- **Quem paga:** o dono do brechó, por assinatura (hipótese de R$ 29 a R$ 59 por mês). Durante o piloto, 30 dias grátis, e a IA ou o usuário cadastram as primeiras peças.
- **Quem compra:** a cliente final, sem cadastro, pagando por **Pix direto para a chave do brechó**. A plataforma nunca recebe nem guarda dinheiro.
- **Proposta de valor:** peça única com reserva por tempo, vitrine para o Instagram, Pix com QR Code, acompanhamento do pedido, entrega e retirada configuráveis, tudo em um link.
- **Aquisição:** abordagem direta no Instagram a brechós que reservam peças por comentário e mensagem. Material previsto: loja de demonstração, vídeo de 30 a 40 segundos, mensagem curta. **Não há registro de que a abordagem tenha começado.**
- **Critério de validação (2 semanas):** de 10 brechós contatados, pelo menos 3 aceitam o piloto e pelo menos 2 dizem que pagariam R$ 29 ou mais depois.

### 1.4 Concorrência e preços observados (pesquisa de novembro de 2026; podem ter mudado)

| Opção | O que faz | Preço observado |
|---|---|---|
| Nuvemshop | Loja virtual completa | Plano gratuito sem mensalidade; plano pago mais barato perto de R$ 69/mês (varia por fonte) |
| Loja Integrada | Catálogo online | Gratuito |
| WhatsApp Business | Catálogo nativo | Gratuito |
| TicTag (app da Nuvemshop) | Gestão de brechó: estoque, consignação, nota fiscal | Plano básico R$ 118/mês |
| Reuzee | App de gestão para brechós | Gratuito |

Lacuna que o produto ataca: vender por Instagram e WhatsApp com peça única, reserva por tempo e Pix. Não foi encontrada ferramenta com esse foco, o que **não prova que não exista**.

Referências de licitações (caso o projeto B seja retomado): Alerta Licitação a R$ 44,90/mês (ou cerca de R$ 30,82/mês no plano anual), Effecti com plano grátis por CNPJ e leitura de edital com IA, ConLicitação com planos pagos, e a plataforma Contrata+Brasil do governo.

### 1.5 Ideias que ficaram no backlog de negócio

- Alertas de licitações para iniciantes, com resumo semanal grátis e preço de R$ 29 a R$ 59/mês.
- Radar de editais culturais (PNAB), começando como boletim por e-mail.
- Mensalidade por Pix Automático para professores particulares, escolinhas e associações. O Pix Automático foi lançado em junho de 2025. Uma fonte indica que só empresas com mais de seis meses de atividade podem oferecer o serviço (verificar).
- Planilhas e templates vendidos em pré-venda, como teste de mercado.

### 1.6 Artefatos relacionados fora desta pasta

- Documento de plano (Claude Doc): `https://claude.ai/artifact/25JerfrpSTV28wEYy1zwe5`
- Loja de demonstração antiga, só no navegador (localStorage): `https://claude.ai/artifact/JBwcdeYykxpFhHEySWm8Li`
- `plano-negocio-online.md`: plano consolidado das duas ideias finalistas, com pesquisa e fontes.

---

## 2. Estado atual e histórico de versões

| Versão | O que entrou | Arquivos | Situação |
|---|---|---|---|
| Base | Vitrine pública por link, reserva atômica com contador, Pix (copia e cola e QR Code), painel do dono com login por link no e-mail, fotos | `schema.sql`, `index.html` | Aplicada e testada pelo usuário |
| 1 | Login por e-mail e senha; avisos de reserva no Telegram | `migracao-1-avisos.sql` | **Login por senha: em uso. Telegram: o usuário adiou; não confirmado** |
| 2 | Resumo no painel, editar peça, vender fora do site, entrega e retirada (texto), alerta no painel, recuperação de senha, Termos e Privacidade | `migracao-2-piloto.sql` | Aplicada (confirmado) |
| 3 | Abas na loja e no painel; Instagram, horário, trocas, sobre, cor, logo | `migracao-3-abas.sql` | Aplicada (confirmado) |
| 4 | Capa, frase, aviso, categoria, descrição, medidas, várias fotos; busca, filtros, favoritas, página da peça, checklist | `migracao-4-vitrine.sql` | Aplicada (confirmado) |
| 5 | Carrossel de fotos na entrada da loja | só `index.html` | Visível em captura de tela do usuário |
| 6 | Departamentos por forma de medição (roupas, calçados, bolsas e acessórios, outros) | só `index.html` | Entregue; sem confirmação explícita |
| 7 | Logística: formas de receber, frete, endereço protegido, mapa, página do pedido, etapas, rastreio, comprovante, "Recebi minha peça", depoimentos, informar pagamento, link de cartão, pagar na retirada | `migracao-5-logistica.sql`, `index.html` | **Entregue; sem confirmação de que foi aplicada. O SQL nunca foi executado em um Postgres real** |
| 8 | Novo visual: cabeçalho fixo, filtros laterais, página da peça em duas colunas, fotos com "contain" sobre fundo desfocado, indicadores de carregamento, rodapé | só `index.html` | Entregue agora; só passou por verificação de sintaxe e simulação |

**Antes de qualquer trabalho novo, confirme com o usuário o que está de fato aplicado** (quais migrações rodaram e qual `index.html` está no GitHub).

---

## 3. Visão geral da arquitetura

```
 Cliente (navegador)                 Dono (navegador)
        |                                   |
        |   index.html (SPA estática)       |
        +-----------------+-----------------+
                          |
              GitHub Pages (hospedagem estática, grátis)
                          |
                          | HTTPS (supabase-js 2.45.4, via CDN jsDelivr)
                          v
   +------------------------------------------------------+
   |                      Supabase                        |
   |  Auth (e-mail + senha)                               |
   |  Postgres: tabelas + RLS + funções RPC               |
   |  Storage: bucket público "fotos"                     |
   |  pg_net (opcional) --> API do Telegram (avisos)      |
   +------------------------------------------------------+

 Serviços externos chamados direto do navegador:
   ViaCEP (busca de CEP, só no painel), Google Maps (iframe e links),
   Waze (links), wa.me (links de WhatsApp), qrcodejs (CDN cdnjs, QR Code do Pix).
```

**Características centrais**

- **Sem servidor próprio e sem etapa de build.** Um único `index.html` com HTML, CSS e JavaScript puro.
- **Toda a segurança está no banco** (RLS e funções `SECURITY DEFINER`), porque a chave do Supabase exposta no site é pública por definição.
- **O dinheiro nunca passa pela plataforma.** O Pix é gerado no navegador (BR Code estático) com a chave do brechó. A confirmação é manual.
- **Multi-loja:** cada conta de dono tem exatamente um brechó (`owner` único), identificado por um `slug` público.

---

## 4. Estrutura do projeto e configuração

### 4.1 Arquivos

| Arquivo | Função |
|---|---|
| `index.html` | Site inteiro. Cerca de 72 KB, uma única tag `<script>` com linhas muito longas |
| `schema.sql` | Banco base: `brechos`, `pecas`, `pedidos`, RLS, funções iniciais, bucket `fotos` |
| `migracao-1-avisos.sql` | `avisos`, `segredos`, `pg_net`, gatilho de aviso por Telegram |
| `migracao-2-piloto.sql` | `entrega_info`, `pedidos.entrega`, nova `reservar_peca`, `editar_peca`, `marcar_peca` |
| `migracao-3-abas.sql` | Colunas de identidade da loja |
| `migracao-4-vitrine.sql` | Capa, categoria, descrição, medidas, fotos; novo `editar_peca` |
| `migracao-5-logistica.sql` | Logística, endereços, depoimentos e várias funções |
| `LEIA-ME.md` | Instalação e notas de cada atualização |

### 4.2 Constantes no topo do script (o usuário precisa preencher a cada novo `index.html`)

- `SUPABASE_URL` e `SUPABASE_KEY`: URL do projeto e chave pública (anon ou publishable).
- `BOT_USER`: usuário do bot do Telegram, sem @.
- `CONTATO`: e-mail exibido nos Termos e na Privacidade.

Se `SUPABASE_URL` ainda começa com `COLE`, o site mostra "Falta configurar".

### 4.3 Configurações obrigatórias no Supabase

- **Authentication, provedor Email:** ativado. A opção "Confirm email" deve ficar **desligada**, ou as contas devem ser criadas manualmente (Authentication, Users, Add user, com Auto Confirm).
- **Authentication, URL Configuration:** *Site URL* e *Redirect URLs* com o endereço do GitHub Pages e também com `/**` no final. Sem isso, e-mails de recuperação apontam para `localhost`.
- **Extensão `pg_net`:** só se for usar o Telegram.
- **SMTP:** o envio padrão do Supabase tem limite muito baixo de e-mails por hora (cerca de 2). Por isso o login principal é por senha.

### 4.4 Hospedagem

GitHub Pages, repositório público, publicação por branch `main`, pasta raiz. O endereço tem o formato `https://USUARIO.github.io/REPOSITORIO/`. Depois de um commit, leva de 1 a 2 minutos; recarregar com Ctrl+F5.

---

## 5. Front-end (`index.html`)

### 5.1 Modelo de execução

- **SPA vanilla.** Um objeto global de estado `S`, funções que devolvem strings HTML (template literals) e uma função `render()` que troca `#app.innerHTML`.
- **Delegação de eventos:** não há handlers por elemento. Elementos usam `data-act="nome"` (e `data-v="valor"`) e um único listener de `click` decide o que fazer. Formulários usam `data-form="nome"` e um único listener de `submit` chama `onSubmit`.
- **Fluxo de uma ação:** o listener altera `S` ou chama o Supabase, e depois chama `render()` ou `refresh()`.
- **Atualização automática:** `setInterval` de 15 s. Na loja usa `quiet()` (recarrega os dados e só redesenha se algo mudou). No painel recarrega e dispara o alerta de nova reserva. As atualizações são ignoradas se um campo está em foco ou um modal aberto.
- **Relógio:** a cada 1 s atualiza os contadores (`[data-exp]`); a cada 4 s gira o carrossel.
- **Carregamento:** `busy(on)` controla uma barra de progresso no topo (`#busy`). `refresh()` e `onSubmit` são envolvidos por ela. A primeira carga mostra esqueletos (`.sk`) e um círculo giratório (`.spin`).
- **Escape de HTML:** toda string do usuário passa por `esc()`. Conteúdo com quebras de linha usa `PL()` ou `PL2()`.

### 5.2 Rotas (todas por URL, sem biblioteca)

| URL | Tela |
|---|---|
| `/` (sem parâmetros) | Painel do dono (login, criação do brechó e abas) |
| `?b=slug` | Loja da cliente, aba Produtos |
| `?b=slug#entrega` ou `#contato` | Abas da loja (`#produtos` é o padrão) |
| `?b=slug&peca=ID` | Página de uma peça |
| `?b=slug&pedido=ID` | Página do pedido da cliente |
| `?p=termos` ou `?p=privacidade` | Páginas legais |

A recuperação de senha volta para `/` com o token no hash e dispara o evento `PASSWORD_RECOVERY`.

### 5.3 Telas e funções principais

| Função | Responsabilidade |
|---|---|
| `lojaView` | Cabeçalho fixo, banner de reserva, hero, aviso, carrossel, selos, Novidades, filtros e lista |
| `listaHTML`, `filtrar`, `card` | Lista de peças, filtros, ordenação, cartão |
| `pecaView` | Página da peça: migalhas, galeria, ficha técnica, descrição, medidas, acordeões |
| `entregaHTML`, `contatoHTML` | Abas Entrega e pagamento e Contato da loja |
| `pedidoView` | Página do pedido da cliente: etapas, valores, endereço, rastreio, recebimento |
| `modalHTML` | Modais: reservar, Pix, recebi, enviar, editar |
| `painelView` | Painel: login, criação do brechó e abas Resumo, Pedidos, Peças, Loja, Entrega, Avisos |
| `cfgFields`, `entregaForm` | Formulários das abas Loja e Entrega |
| `acoesPedido` | Botões de etapa e WhatsApp por pedido |
| `resumo`, `checklist` | Cartões de números e checklist "Complete sua loja" |
| `paginaView`, `rodapeLoja` | Termos e Privacidade; rodapé da loja |
| `loadLoja`, `loadPainel`, `checkMeu`, `refresh`, `quiet` | Carregamento de dados |
| `pix`, `tlv`, `crc` | Geração do código Pix copia e cola (BR Code estático) |
| `calcFrete`, `fretePrev`, `camposEnt`, `modsAtivas`, `tabLocal` | Frete e campos da reserva |
| `tamCampo`, `depDe` | Tamanhos por categoria e departamento |
| `comprimir` | Redução de fotos no navegador |
| `girar`, `aplicarCor`, `avisoPainel`, `bip`, `toast`, `busy`, `imgs` | Utilidades de interface |

### 5.4 Estado `S` (chaves principais)

`b` (brechó atual), `pecas`, `pedidos` (só painel), `user`, `meu` (pedido da cliente, também em localStorage), `modal`, `aba`, `pab` (aba do painel), `peca` (peça aberta), `ped` (página do pedido aberta), `dep`, `cat`, `filtro` (tamanho), `faixa`, `ord`, `q` (busca), `fav` (só favoritas), `end` (endereço liberado), `depo` (depoimentos), `chat` (Id do Telegram), `ender` (endereço do dono), `recup` (modo nova senha), `slide`, `pausa`.

**localStorage:** `pedido:SLUG` (último pedido da cliente naquela loja) e `fav:SLUG` (lista de peças favoritas).

### 5.5 Ações (`data-act`)

| Ação | Efeito |
|---|---|
| `aba` | Muda a aba da loja e fecha peça e pedido |
| `dep`, `cat`, `filtro`, `favfiltro`, `favnav`, `crumb` | Navegação e filtros da vitrine |
| `peca`, `voltar`, `foto`, `fav` | Abrir peça, voltar, trocar foto, favoritar |
| `reservar`, `pedido`, `verpedido`, `fechar` | Abrir reserva, Pix, página do pedido; fechar modal |
| `copiar`, `link` | Copiar Pix ou texto para a área de transferência |
| `informado` | Marca "cliente informou o pagamento" |
| `recebi` | Abre o modal de recebimento |
| `slide`, `rolar` | Carrossel e rolagem até os filtros |
| `pab`, `sair`, `esqueci` | Aba do painel, logout, recuperação de senha |
| `pago`, `cancelar`, `etapa` | Gestão de pedidos pelo dono |
| `editar`, `vendida`, `disponibilizar`, `remover` | Gestão de peças pelo dono |
| `cep`, `testeaviso` | Busca de CEP; teste do Telegram |

### 5.6 Formulários (`data-form`)

| Formulário | Destino |
|---|---|
| `login` | `auth.signInWithPassword` ou `signUp` (botão decide) |
| `novasenha` | `auth.updateUser` |
| `novo`, `cfg` | `brechos` (insert ou update); logo e capa vão ao Storage |
| `ent` | `brechos` update e `enderecos` upsert |
| `peca` | Upload de até 5 fotos e insert em `pecas` |
| `editar` | RPC `editar_peca` |
| `aviso` | `avisos` upsert |
| `reserva` | RPC `reservar_peca` |
| `recebi` | RPC `confirmar_recebimento` |
| `enviar` | Upload do comprovante e RPC `atualizar_pedido` |

### 5.7 Convenções e armadilhas de código

- Quase todo HTML é montado com template literals aninhados. **Erros de crase e de chave já ocorreram** (por exemplo uma crase fechada com apóstrofo, e a função de envio de formulários sem a chave de fechamento). Sempre rode a verificação de sintaxe depois de editar.
- As edições foram feitas por scripts Python que substituem trechos exatos (`rep`) ou fatiam entre marcadores (`cut`). Funciona, mas é frágil. Veja a melhoria de modularizar o código.
- `FormData` com campo `multiple` só devolve o último arquivo em `Object.fromEntries`. Use `getAll`.
- Os slides do carrossel ficam empilhados: o slide invisível precisa de `pointer-events:none`, senão o clique abre a peça errada (corrigido).
- Os campos do formulário de reserva mudam conforme a forma de receber; as mudanças são tratadas por listeners de `change` e `input`, e o frete é recalculado em `fretePrev`.

### 5.8 Visual e experiência

- **Tokens:** variáveis CSS (`--bg`, `--fg`, `--mut`, `--card`, `--bd`, `--ac`, `--acf`, `--ok`, `--wr`, `--sh`), com tema escuro automático. A cor da loja substitui `--ac`, e o contraste do texto é calculado pela luminância.
- **Layout:** cabeçalho fixo com marca, abas, favoritas e "Meu pedido". Em telas largas, filtros ficam numa coluna lateral fixa. Em telas estreitas, viram um bloco recolhível. A página da peça tem duas colunas, com galeria fixa à esquerda.
- **Fotos:** exibidas com `object-fit:contain` sobre uma cópia da mesma foto desfocada e ampliada (técnica de mercado), para nunca cortar a peça. Isso corrigiu o problema relatado de fotos horizontais, como calçados, aparecerem cortadas no carrossel em telas largas. A capa da loja continua com `cover`.
- **Carregamento:** esqueleto brilhante enquanto as fotos carregam, entrada suave, barra de progresso global, esqueleto de cartões na primeira carga.
- **Acessibilidade:** foco visível, rótulos nas fotos e botões, respeito a "reduzir movimento".

---

## 6. Back-end (Supabase)

### 6.1 Tabelas

**`brechos`** (uma por conta)

| Coluna | Observação |
|---|---|
| `id`, `owner` (único, FK `auth.users`), `slug` (único, regex `^[a-z0-9-]{3,40}$`), `nome`, `whats`, `pix`, `cidade`, `reserva_min` (1 a 120, padrão 30), `criado_em` | Base |
| `entrega_info` | Texto livre de entrega e retirada |
| `instagram`, `horario`, `sobre`, `trocas`, `cor`, `logo_url` | Identidade (migração 3) |
| `endereco` | **Legado, público, não usado desde a migração 5.** Veja a seção 14 |
| `capa_url`, `frase`, `aviso` | Vitrine (migração 4) |
| `bairro`, `uf`, `endereco_protegido`, `retirada_ativa` (padrão verdadeiro), `entrega_local_ativa`, `envio_ativo`, `aceita_pagar_retirada`, `retirada_horarios`, `entrega_local_tabela`, `entrega_local_taxa`, `envio_regioes` (jsonb), `frete_gratis_acima`, `prazo_postagem`, `embalagem`, `link_pagamento` | Logística (migração 5) |

**`pecas`**: `id`, `brecho_id`, `titulo`, `tam`, `marca`, `estado`, `preco` (maior que zero), `foto_url` (capa), `status` (`disponivel`, `reservada`, `vendida`), `criado_em`, `categoria`, `descricao`, `medidas`, `fotos` (lista de URLs, até 5).

**`pedidos`**: `id`, `brecho_id`, `peca_id`, `nome`, `whats`, `status` (`ativo`, `pago`, `expirado`, `cancelado`), `expira_em`, `criado_em`, `entrega` (rótulo), `metodo` (`retirada`, `local`, `envio`), `slot`, `bairro`, `cep`, `uf`, `endereco_entrega`, `frete`, `total`, `pagamento` (`pix` ou `retirada`), `pagamento_informado`, `etapa` (`aguardando`, `pago`, `preparando`, `enviado`, `pronto`, `entregue`), `rastreio`, `comprovante_url`, `recebido`.

**`enderecos`** (um por brechó): `brecho_id`, `cep`, `rua`, `numero`, `complemento`, `instrucoes`.

**`depoimentos`**: `id`, `brecho_id`, `pedido_id` (único), `nome` (só o primeiro nome), `texto`, `nota` (1 a 5), `criado_em`.

**`avisos`** (migração 1): `brecho_id`, `telegram_chat_id`. **`segredos`** (migração 1): `chave`, `valor` (guarda `telegram_token`).

### 6.2 Segurança por linha (RLS)

| Tabela | Leitura | Escrita |
|---|---|---|
| `brechos` | Pública | Só o dono (insert e update) |
| `pecas` | Pública | Dono insere; dono apaga só se `disponivel`; **não há update direto** (usa funções) |
| `pedidos` | Só o dono | Só por funções |
| `enderecos` | Só o dono | Só o dono |
| `depoimentos` | Pública | Só por função; o dono pode apagar |
| `avisos` | Só o dono | Só o dono |
| `segredos` | Ninguém pelo site | Ninguém pelo site |

### 6.3 Funções (todas `SECURITY DEFINER`, `search_path = public`)

| Função | Quem chama | Regra |
|---|---|---|
| `liberar_expiradas()` | Todos | Pedidos `ativo` vencidos viram `expirado`; peças `reservada` voltam a `disponivel` |
| `reservar_peca(p_peca, p_nome, p_whats, p_metodo, p_slot, p_bairro, p_uf, p_cep, p_endereco, p_pagamento)` | Todos | Trava a peça (`FOR UPDATE`), valida disponibilidade, limite de 2 reservas ativas por WhatsApp, forma de receber, frete, endereço e pagamento; cria o pedido |
| `meu_pedido(p_id)` | Todos (quem tem o código) | Devolve os dados do pedido; inclui o endereço da loja só se permitido |
| `endereco_loja(p_brecho, p_pedido)` | Todos | Endereço público se a loja não o protege; senão só com pedido pago |
| `informar_pagamento(p_id)` | Todos | Marca `pagamento_informado` em pedido `ativo` |
| `resolver_pedido(p_id, p_acao)` | Dono | `pago`: pedido e etapa viram `pago`, peça `vendida`. Outra ação: cancela e devolve a peça |
| `atualizar_pedido(p_id, p_etapa, p_rastreio, p_comprovante)` | Dono | Só pedidos `pago`; etapas `preparando`, `enviado`, `pronto`, `entregue`; comprovante só com `https://` |
| `confirmar_recebimento(p_id, p_texto, p_nota)` | Todos (quem tem o código) | Só `pago` em etapa `enviado`, `pronto` ou `entregue`; fecha o pedido; cria depoimento opcional |
| `editar_peca(...)` | Dono | Bloqueia peça `reservada` |
| `marcar_peca(p_id, p_status)` | Dono | `vendida` ou `disponivel`; cancela pedidos ativos da peça |
| `status_pedido(p_id)` | Todos | **Legado, sem uso no site atual** |
| `enviar_telegram`, `avisar_reserva` (gatilho), `testar_aviso()` | Interno, gatilho e dono | Aviso por Telegram a cada novo pedido, se houver Id e token; erros silenciosos |

**Códigos de erro devolvidos pelo banco:** `indisponivel`, `limite`, `entrega_indisponivel`, `metodo_invalido`, `endereco_obrigatorio`, `pagamento_invalido`, `nao_permitido`, `status_invalido`, `etapa_invalida`. O site traduz os de reserva em `ERR`.

### 6.4 Storage

Bucket público `fotos`. Leitura pública. Envio apenas para usuários autenticados, dentro da própria pasta (`USER_ID/...`). Caminhos usados: `ID/timestamp-n.jpg` (peças), `ID/logo-...`, `ID/capa-...`, `ID/envio-...` (comprovante de postagem).

### 6.5 Telegram (opcional)

O dono abre o bot, toca em Iniciar, obtém o próprio Id no `@userinfobot` e cola no painel. Um gatilho em `pedidos` chama a API do Telegram via `pg_net`. O token do bot fica na tabela `segredos`, inacessível pelo site. Não há webhook, então o vínculo é manual.

### 6.6 Ordem de execução do SQL

`schema.sql`, depois `migracao-2`, `3`, `4`, `5` (e `1` se for usar Telegram; a 1 é independente). Os arquivos usam `if not exists` e `drop ... if exists` na maior parte, mas as políticas do `schema.sql` e da migração 1 não são idempotentes. **Não rode `schema.sql` duas vezes.**

---

## 7. Regras de negócio

**Peças e estoque**
- RN-01. Cada peça é única (estoque 1) e tem um status: `disponivel`, `reservada` ou `vendida`.
- RN-02. A reserva é atômica: duas pessoas nunca reservam a mesma peça. A segunda recebe "Essa peça acabou de ser reservada".
- RN-03. O dono só edita uma peça que não esteja reservada; só remove uma peça disponível.
- RN-04. "Vendida fora do site" marca a peça como vendida e cancela reservas ativas dela. "Voltar à venda" a devolve à vitrine.
- RN-05. Cada peça tem até 5 fotos; a primeira é a capa da peça.

**Reserva**
- RN-06. O prazo da reserva é `reserva_min` (1 a 120 minutos; padrão 30). Com "pagar na retirada", a reserva dura 24 horas.
- RN-07. A expiração é "preguiçosa": acontece quando alguém consulta os dados (não há tarefa agendada).
- RN-08. Cada WhatsApp pode ter no máximo 2 reservas ativas por brechó.
- RN-09. Nome e WhatsApp são obrigatórios. Não há cadastro nem senha para a cliente.

**Formas de receber e frete**
- RN-10. O dono liga ou desliga **retirada** (ligada por padrão), **entrega local** e **envio**. Se nada estiver ligado, a loja oferece retirada.
- RN-11. Retirada: frete zero; a cliente escolhe um horário se o dono cadastrou horários.
- RN-12. Entrega local: o frete vem da tabela de bairros ("Bairro: valor", uma linha por bairro, comparação sem diferenciar maiúsculas); se o bairro não estiver na tabela, usa a taxa única; se não houver nenhuma, é indisponível.
- RN-13. Envio: o frete vem da região do estado informado (Sudeste, Sul, Centro-Oeste, Nordeste, Norte). Região sem valor cadastrado é indisponível.
- RN-14. Frete grátis: para entrega local e envio, se o preço da peça for maior ou igual a `frete_gratis_acima`. O limite compara o preço da peça, sem o frete.
- RN-15. Entrega local e envio exigem endereço. O total do pedido é preço mais frete. **O frete é sempre recalculado no banco**, nunca confiado ao navegador (a prévia na tela é só informativa).
- RN-16. Não há cálculo automático dos Correios; os valores são tabelas do dono.

**Pagamento**
- RN-17. O pagamento é por Pix direto à chave do brechó. O código é gerado no navegador (BR Code estático) com o valor total, o nome do brechó (até 25 caracteres) e a cidade (até 15). A plataforma nunca recebe dinheiro.
- RN-18. A confirmação é **manual**: o dono confere o Pix no banco e clica em "Confirmar pagamento". Só então a peça vira vendida.
- RN-19. A cliente pode tocar em "Já paguei" para sinalizar. Isso apenas destaca o pedido no painel; não confirma nada.
- RN-20. O dono pode cadastrar um link de pagamento por cartão (deve começar com `https://`). Ele é só um botão para um serviço externo.
- RN-21. "Pagar na retirada" só existe se o dono aceitar e a forma de receber for retirada.

**Acompanhamento**
- RN-22. Etapas após o pagamento: preparando, depois pronto para retirada (retirada) ou enviado/saiu para entrega (entrega local e envio), depois entregue.
- RN-23. O rastreio (até 60 caracteres) e a foto do comprovante de postagem aparecem na página do pedido. O link de rastreamento dos Correios é genérico (não leva o código).
- RN-24. A cliente confirma o recebimento quando o pedido está enviado ou pronto. Isso fecha o pedido e permite nota (1 a 5) e comentário. Cada pedido gera no máximo um depoimento.
- RN-25. A aba Contato mostra os 6 depoimentos mais recentes que tenham texto, só com o primeiro nome.
- RN-26. Cada pedido tem um código curto (8 primeiros caracteres do identificador) mostrado como `#XXXXXXXX`.

**Endereço da loja**
- RN-27. O endereço completo fica numa tabela à parte. Se o dono não o protege, é público. Se protege, só aparece para quem tem um pedido pago (na página do pedido e na aba Contato daquele pedido). Antes disso, aparecem só bairro, cidade e estado.
- RN-28. O mapa usa o endereço liberado; se protegido, só bairro e cidade.

**Vitrine**
- RN-29. Departamentos e tamanhos: **Roupas** (vestidos, blusas, calças e saias, casacos) com PP, P, M, G, GG, XG e 34 a 48; **Calçados** com 33 a 44, exibidos como "Nº 38"; **Bolsas e acessórios** com "Único"; **Outros** com texto livre. No cadastro a categoria vem primeiro e a lista de tamanhos se ajusta. Peças antigas sem categoria aparecem em Outros.
- RN-30. Na loja: departamento, depois categoria, depois tamanho (só os do departamento escolhido). Há busca por texto (título, marca e descrição), faixa de preço e ordenação (mais novas, menor preço, maior preço).
- RN-31. Favoritas ficam só no aparelho da cliente.
- RN-32. Selo "Novo": peça disponível criada nos últimos 7 dias.
- RN-33. Bloco "Novidades": aparece quando há mais de 4 peças disponíveis e nenhum filtro ativo; mostra as 4 mais recentes.
- RN-34. Carrossel de entrada: aparece com 2 ou mais peças disponíveis que tenham foto; usa até 6 peças, as mais recentes; troca a cada 4 segundos; pausa com o mouse; não gira para quem pediu menos movimento.
- RN-35. Fotos: reduzidas no navegador antes do envio (maior lado de 1400 px e qualidade 0,85; capa a 1600 px; comprovante a 1200 px). Exibidas inteiras sobre fundo desfocado.

**Painel do dono**
- RN-36. Cada conta tem um brechó. O `slug` é único e só aceita letras minúsculas, números e hífen (3 a 40 caracteres).
- RN-37. Resumo: disponíveis, reservadas, vendidas, "total vendido" (soma do preço das peças marcadas como vendidas, inclusive fora do site) e pedidos aguardando pagamento.
- RN-38. Checklist "Complete sua loja", com 6 itens: logo, capa, 10 ou mais peças, regra de entrega e retirada, contato completo (Instagram e bairro) e Telegram. Some quando tudo está completo.
- RN-39. Alerta de reserva: o painel aberto se atualiza a cada 15 s; se o número de pedidos aguardando cresce, toca um som e mostra "Nova reserva!", e o título da aba mostra a contagem.
- RN-40. Mensagens de WhatsApp para a cliente já saem prontas, com o código e o link do pedido; o número recebe o prefixo 55 se não tiver.

**Conta e legal**
- RN-41. Login por e-mail e senha (mínimo de 6 caracteres). Recuperação por e-mail sujeita ao limite do Supabase.
- RN-42. Termos de uso e Política de privacidade são **modelos básicos** e precisam de revisão profissional antes de uso com clientes reais.
- RN-43. A cor da loja precisa ser um hexadecimal válido. O texto sobre a cor é escolhido por luminância.

---

## 8. Casos de uso

### Dono do brechó

- **UC-01 Criar conta e entrar.** Pré: conta criada por ele ("Criar conta", se "Confirm email" estiver desligado) ou pelo operador no Supabase. Fluxo: e-mail e senha, "Entrar". Exceção: erro de credencial ou limite de e-mail aparece como aviso com a mensagem do Supabase.
- **UC-02 Recuperar senha.** Digita o e-mail, "Esqueci minha senha", abre o link recebido e define a nova senha. Sujeito ao limite de e-mails.
- **UC-03 Criar o brechó.** Preenche nome, endereço do link (`slug`), WhatsApp (com 55 e DDD), minutos de reserva, chave Pix, cidade e (opcional) texto de entrega. Resultado: loja disponível em `?b=slug`.
- **UC-04 Configurar a identidade (aba Loja).** Instagram, horário, trocas, sobre, frase da capa, aviso, foto de capa, cor e logo.
- **UC-05 Configurar entrega e localização (aba Entrega).** Formas de receber, CEP com busca automática, endereço, instruções de chegada, proteção do endereço, horários de retirada, taxas por bairro, taxa única, frete por região, frete grátis, prazo de postagem, embalagem, link de cartão e pagar na retirada.
- **UC-06 Cadastrar peça.** Categoria, título, tamanho (lista conforme a categoria), marca, estado, preço, descrição, medidas e até 5 fotos.
- **UC-07 Editar peça**, **UC-08 Marcar como vendida fora do site e voltar à venda**, **UC-09 Remover peça** (conforme RN-03 e RN-04).
- **UC-10 Acompanhar o resumo e o checklist.**
- **UC-11 Gerir pedidos.** Ver quem informou o pagamento, confirmar o pagamento ou cancelar, avançar as etapas, registrar rastreio e foto do comprovante, abrir o WhatsApp da cliente com a mensagem pronta.
- **UC-12 Receber avisos.** Alerta no painel (som, aviso e contagem na aba) e, opcionalmente, mensagem no Telegram.
- **UC-13 Divulgar.** Copiar o link da loja (aba Resumo) para a bio do Instagram.

### Cliente

- **UC-20 Navegar pela loja.** Abre o link, vê capa, carrossel e peças; usa busca, departamento, categoria, tamanho, preço e ordenação; abre as abas Entrega e pagamento e Contato.
- **UC-21 Ver uma peça.** Galeria, ficha técnica, descrição, medidas, informações de entrega e pagamento, peças parecidas, compartilhar no WhatsApp, favoritar.
- **UC-22 Reservar.** Escolhe a peça, informa nome, WhatsApp e forma de receber (horário, bairro ou endereço, UF e CEP, conforme o caso), vê o frete e o total e confirma. Erros: peça acabou de ser reservada, limite de 2 reservas, entrega indisponível para a região, endereço obrigatório.
- **UC-23 Pagar.** Vê o valor, o QR Code e o copia e cola, a contagem regressiva, o link de cartão (se houver). Paga no aplicativo do banco e toca em "Já paguei: avisar no WhatsApp".
- **UC-24 Acompanhar o pedido.** Pela página do pedido (link próprio, que também chega na mensagem do dono): etapas, valores, onde retirar (com rota), rastreio e comprovante.
- **UC-25 Confirmar o recebimento e deixar depoimento** (RN-24).
- **UC-26 Voltar ao pedido depois.** O navegador guarda o último pedido daquela loja; também é possível abrir o link `?pedido=`.

### Operador (o usuário, dono do produto)

- **UC-30 Preparar o projeto do zero** (seção 12.1).
- **UC-31 Criar contas de brechós no piloto** (Authentication, Users, Add user, com Auto Confirm), cadastrar as primeiras peças com o dono e só então passar a senha.
- **UC-32 Aplicar uma atualização:** rodar o SQL novo, colar as chaves no novo `index.html` e substituir o arquivo no GitHub.
- **UC-33 Moderar:** remover um depoimento ou uma conta diretamente no Supabase (não há tela para isso).

---

## 9. Fluxos principais

### 9.1 Reserva e pagamento

1. A cliente toca em "Reservar". O navegador monta o formulário conforme as formas de receber ligadas.
2. Ao enviar, chama `reservar_peca`. O banco trava a peça, libera reservas vencidas, valida tudo, calcula o frete e cria o pedido com validade.
3. O navegador chama `meu_pedido`, guarda o pedido em `localStorage` e abre o modal do Pix com o total.
4. A cliente paga no banco e toca em "Já paguei". O navegador chama `informar_pagamento` e abre o WhatsApp do brechó em outra aba.
5. O gatilho do Telegram (se ativo) avisa o dono assim que o pedido nasce. O painel aberto também avisa em até 15 s.
6. O dono confere o Pix, clica em "Confirmar pagamento" (`resolver_pedido`). A peça vira vendida e o pedido vira `pago`.
7. Se o prazo vencer sem confirmação, `liberar_expiradas` expira o pedido e a peça volta para a vitrine.

### 9.2 Entrega ou retirada

1. O dono avança as etapas no painel. Para "Enviado" ou "Saiu para entrega" ele pode informar o rastreio e a foto do comprovante.
2. A cliente vê as etapas, o rastreio e (se retirada) o endereço, liberado depois do pagamento quando protegido.
3. A cliente toca em "Recebi minha peça", escolhe nota e comentário opcionais, e o pedido é fechado.

---

## 10. Decisões técnicas

| # | Decisão | Motivo | Alternativas descartadas |
|---|---|---|---|
| D1 | Site estático (um `index.html`) em GitHub Pages | Custo zero, sem servidor, o usuário publica pela interface web | Next.js com servidor próprio; hospedagens pagas |
| D2 | Supabase (Postgres, Auth, Storage) como backend | Plano gratuito, SQL, regras de acesso no banco, nenhum servidor para manter | Firebase; backend próprio |
| D3 | JavaScript puro, sem framework nem build | O usuário não executa código local; arquivo único fácil de substituir | React, Vue |
| D4 | Regras de acesso no banco (RLS) e funções `SECURITY DEFINER` | A chave do site é pública, então a proteção real tem de estar no banco | Validar só no navegador |
| D5 | Reserva atômica em função SQL com `SELECT ... FOR UPDATE` | Evita duas reservas da mesma peça | Checar no navegador |
| D6 | Expiração preguiçosa (`liberar_expiradas`) | Sem tarefa agendada; simples | `pg_cron`, Edge Function |
| D7 | Pix direto para o brechó, BR Code estático gerado no navegador, confirmação manual | A plataforma não segura dinheiro, sem CNPJ nem taxas; exigência do orçamento zero | Gateway (Asaas, Mercado Pago) com confirmação automática: exige CNPJ, tarifas e contas por brechó; deixado para depois do piloto |
| D8 | Login por e-mail e senha | O envio de e-mail padrão do Supabase é limitado a cerca de 2 por hora, o que travava o cadastro de vários brechós | Link mágico (substituído) |
| D9 | Frete recalculado no banco; tabelas definidas pelo dono | Segurança contra manipulação; APIs dos Correios exigem contrato e chave secreta, que não pode ficar no site | Cotação automática |
| D10 | Endereço em tabela separada, entregue por função conforme a regra da loja | A tabela `brechos` é pública; muitos brechós funcionam em casa | Colunas de endereço em `brechos` |
| D11 | Página do pedido com o UUID como "chave de acesso" | Cliente sem conta; basta o link | Cadastro da cliente |
| D12 | Telegram via `pg_net` e Id colado manualmente | Sem servidor nem webhook | Edge Function com webhook; WhatsApp oficial (tem custo) |
| D13 | Consulta periódica (15 s) em vez de tempo real | Mais simples; recarga silenciosa evita piscar | Realtime do Supabase |
| D14 | Departamento derivado da categoria, no código (sem coluna no banco) | Sem migração; as listas de tamanhos são fixas | Coluna `departamento` |
| D15 | Fotos reduzidas no navegador antes do envio | Economiza espaço no plano gratuito | Enviar o original |
| D16 | Fotos exibidas com `contain` sobre fundo desfocado | Nunca corta a peça, em qualquer proporção e tela | `cover` com ponto focal escolhido pelo dono |
| D17 | Abas da loja por hash (`#entrega`) e peça e pedido por parâmetro | Links diretos compartilháveis, sem biblioteca de rotas | Rotas por caminho (não funcionam em hospedagem estática) |
| D18 | Mapa por iframe do Google Maps sem chave | Custo zero | Mapas pagos; OpenStreetMap exige coordenadas |
| D19 | Busca de CEP pelo ViaCEP, só no painel | Gratuito, uma consulta por cadastro | CEP pelo cliente na reserva (UF é escolhida à mão) |
| D20 | Estado da cliente em `localStorage` (último pedido, favoritas) | Sem conta | Banco |
| D21 | Cada conta, um brechó | Simplifica regras de acesso | Várias lojas por conta |

---

## 11. Segurança, privacidade e LGPD

- **Chave pública:** `anon` ou `publishable` pode ficar no site. **Nunca** colocar `service_role` ou `sb_secret_...`. Se vazar, gerar uma chave nova no Supabase imediatamente.
- **Token do Telegram:** só na tabela `segredos`, sem leitura pelo site. A função que envia mensagens tem a permissão de execução revogada para o site, para ninguém usar o bot.
- **Dados pessoais coletados:** nome e WhatsApp da cliente; endereço quando há entrega ou envio; e-mail do dono. Ficam no banco do Supabase e são lidos só pelo dono do brechó (e pela cliente, pelo link do pedido).
- **Escape de HTML** em todo texto do usuário. **Não há Content Security Policy** configurada no GitHub Pages.
- **Riscos conhecidos:** sem CAPTCHA (a defesa é o limite de 2 reservas por WhatsApp); quem tem o link do pedido vê o endereço da loja depois do pagamento (se protegido) e os dados do pedido; o estado (UF) é informado pela cliente e altera o frete (prejudica o próprio brechó, que vê o endereço); logo e capa guardam uma URL sem validação (só o dono as define); a coluna legada `brechos.endereco` continua pública se tiver dados antigos.
- **Termos e Política:** são modelos. A Política cita nome, WhatsApp e endereço, e usa o e-mail definido em `CONTATO`.
- **Quando houver cobrança:** será necessário CPF ou CNPJ, identificar o fornecedor no site e revisar os documentos legais com um contador ou advogado.

---

## 12. Operação

### 12.1 Montar do zero

1. Criar projeto no Supabase (plano gratuito).
2. No SQL Editor, rodar `schema.sql` e depois `migracao-2`, `3`, `4` e `5` (e `1`, se for usar Telegram).
3. Em Settings, API, copiar a URL e a chave pública.
4. Em Authentication, Sign In / Providers, Email: ativado e, se achar a opção, desligar "Confirm email". Senão, criar contas manualmente com Auto Confirm.
5. Criar um repositório público no GitHub, enviar o `index.html` com as chaves coladas, ativar Settings, Pages, Deploy from a branch, `main`, `/ (root)`.
6. No Supabase, Authentication, URL Configuration: Site URL com o endereço do Pages; Redirect URLs com o endereço e com `/**`.
7. Entrar no endereço principal, criar a conta e o brechó, preencher as abas Loja e Entrega, cadastrar peças.

### 12.2 Atualizar o site

Rodar o SQL novo (se houver), editar o `index.html` colando de novo `SUPABASE_URL`, `SUPABASE_KEY`, `BOT_USER` e `CONTATO`, subir para o GitHub no lugar do antigo (Add file, Upload files), esperar de 1 a 2 minutos e recarregar com Ctrl+F5.

### 12.3 Telegram

Criar um bot no `@BotFather` (guardar token e usuário). Rodar `migracao-1`. Guardar o token com `insert into segredos (chave, valor) values ('telegram_token', 'SEU_TOKEN') on conflict (chave) do update set valor = excluded.valor;`. Cada dono toca em Iniciar no bot, pega o Id no `@userinfobot`, cola no painel e usa "Enviar teste". O bot não precisa de comandos.

### 12.4 Problemas já encontrados e solução

| Sintoma | Causa | Solução |
|---|---|---|
| "Não foi possível enviar o link" no login | Limite de e-mails do Supabase (cerca de 2 por hora) ou chave errada | Esperar, usar login com senha, criar contas pelo painel; conferir a URL e a chave |
| Link do e-mail abre `localhost` | Site URL padrão do Supabase | Configurar Site URL e Redirect URLs |
| Não acha "Confirm email" | O painel novo mudou de lugar | Procurar o bloco de cadastros acima da lista de provedores; senão, plano B com Auto Confirm |
| Mudança não aparece no site | Cache e atraso do GitHub Pages | Aguardar 1 a 2 minutos e usar Ctrl+F5 |
| Bot "não tem comando" | É normal: só envia avisos | Tocar em Iniciar e usar o Id |
| Fotos horizontais cortadas no carrossel | `cover` em contêiner largo | Corrigido na Atualização 8 (`contain` com fundo desfocado) |
| Fotos novas ficam borradas em tela grande | Reduzidas a 900 px (antes da Atualização 8) | Novas fotos usam 1400 px; fotos antigas continuam no tamanho antigo e precisam ser reenviadas |
| Projeto do Supabase pausado | Plano gratuito pausa projetos inativos | Reativar no painel; uso regular evita |

---

## 13. Qualidade e testes

**O que foi verificado**
- Sintaxe do JavaScript (`node --check`) após cada atualização.
- Uma simulação em Node, com navegador e Supabase falsos, que monta todas as telas (loja, abas, peça, pedido, modais, abas do painel, rodapé) e testa o cálculo de frete e o código Pix. Todas passaram na versão atual.
- Essas verificações já pegaram erros reais (aspas, chaves, ordem de declarações).

**O que NÃO foi verificado**
- Nenhum arquivo SQL foi executado em um Postgres real. **A migração 5, em especial, é grande e pode ter erro de sintaxe.** Se falhar, pegue a mensagem de erro e corrija o trecho indicado.
- O fluxo completo contra um Supabase real (reserva com frete, página do pedido, etapas, recebimento, depoimentos, Telegram).
- O código Pix em aplicativos de banco diferentes (o usuário deve abrir o QR no banco e conferir nome e valor).
- Navegadores e celulares variados, desempenho com muitas peças, e-mails de recuperação de senha.

**Roteiro de teste manual (15 a 20 minutos)**
1. Entrar com senha; conferir os cartões do Resumo e o checklist.
2. Preencher as abas Loja e Entrega; abrir a loja em aba anônima e conferir cabeçalho, capa, carrossel, filtros, abas Entrega e Contato (mapa).
3. Cadastrar uma bolsa, um sapato e uma blusa, com 3 fotos em uma delas; conferir tamanhos por departamento e a galeria.
4. Reservar com cada forma de receber; conferir frete, total e Pix no banco.
5. Confirmar o pagamento e avançar as etapas; conferir a página do pedido (endereço liberado, rastreio, comprovante).
6. "Recebi minha peça" com comentário; conferir o depoimento na aba Contato.
7. Editar, marcar como vendida fora do site e devolver à venda.
8. Abrir Termos e Privacidade; conferir o e-mail de contato.

---

## 14. Limitações conhecidas e dívidas técnicas

1. **Chaves coladas a cada atualização.** Melhoria prioritária: mover `SUPABASE_URL`, `SUPABASE_KEY`, `BOT_USER` e `CONTATO` para um arquivo separado `config.js`, que o usuário edita uma vez e nunca mais precisa tocar. O `index.html` passaria a carregá-lo.
2. Código em um único arquivo com linhas muito longas e strings aninhadas: difícil de editar à mão e propenso a erro. Dividir em módulos e, se possível, adotar um passo de build simples.
3. Sem testes automatizados além da simulação do Apêndice A.
4. A migração 5 precisa ser executada e validada em um banco real.
5. Duplicidades: o campo `cidade` aparece nas abas Loja e Entrega; `pedidos.entrega` (rótulo) e `pedidos.metodo` guardam quase a mesma coisa; a coluna `brechos.endereco` e a função `status_pedido` são legadas.
6. Reserva com pagamento na retirada mostra o contador como "1440:00" em vez de horas.
7. O dono não consegue remover um depoimento, trocar fotos de uma peça existente nem alterar a senha dentro do painel.
8. Um único brechó por conta; sem painel de operador para você ver todos os brechós.
9. O cálculo de frete depende do estado informado pela cliente.
10. Prévia do link no WhatsApp e no Instagram mostra um título genérico, porque o site é montado no navegador. Resolver exigiria renderização no servidor.
11. Reservas só são liberadas quando alguém consulta o banco (expiração preguiçosa). Em loja parada, a peça continua marcada como reservada até o próximo acesso.
12. Não há limpeza de dados antigos nem política de retenção.
13. Dependência de serviços de terceiros sem contrato: ViaCEP e incorporação do Google Maps podem mudar ou limitar o uso.

---

## 15. Roadmap sugerido

**Antes do piloto**
1. Confirmar o que está aplicado; executar e corrigir a migração 5; fazer o teste manual completo.
2. Criar o `config.js` (item 1 da seção 14).
3. Revisar Termos e Privacidade com profissional; conferir o Pix em dois bancos.

**Durante o piloto**
4. Loja de demonstração com 10 ou mais peças; vídeo de 30 a 40 segundos; abordar 10 brechós (modelo no Apêndice C); medir o critério da seção 1.3.
5. Tela do dono para remover depoimentos e trocar fotos; troca de senha no painel; sacola com várias peças em um único Pix.

**Depois de validar**
6. Cobrança de mensalidade (CPF ou CNPJ, gateway); confirmação automática do Pix; SMTP próprio; estatísticas de visitas e cliques; painel do operador; lista de espera por tamanho; domínio próprio; prévia de link por renderização no servidor; taxa por região via serviço de frete com chave guardada em servidor.

---

## 16. Como falar com este usuário

- Português do Brasil, tom direto, passos numerados com o nome exato dos botões e menus.
- Prefere que a IA proponha e ele aprove ("sim", "faz isso"). Responde bem a recomendações claras e a tabelas comparativas.
- Quer aparência profissional e, ao mesmo tempo, "complexa" (que transmita bagagem), com navegação fácil.
- Já pediu repetidamente para **ver imagens** e diagramas do fluxo; as capturas de tela que ele envia são a melhor forma de diagnosticar problemas.
- Valoriza honestidade sobre o que não foi testado e sobre custos escondidos.

---

## 17. Referências

- Supabase: Auth, RLS, funções RPC, Storage e `pg_net` (documentação oficial).
- GitHub Pages (documentação oficial).
- Pix BR Code estático (especificação do Banco Central, campos `000201`, `26`, `52`, `53`, `54`, `58`, `59`, `60`, `62` e CRC16 com polinômio 0x1021).
- ViaCEP (`https://viacep.com.br/ws/CEP/json/`).
- Pesquisa de mercado feita em novembro de 2026 e fontes: ver `plano-negocio-online.md` e o Claude Doc do plano.

---

## Apêndice A: verificação antes de entregar

**1. Sintaxe do script**

```bash
python3 - <<'PY'
import re
s=open('index.html',encoding='utf-8').read()
open('/tmp/app.js','w',encoding='utf-8').write(re.findall(r'<script>(.*?)</script>',s,re.S)[-1])
PY
node --check /tmp/app.js
```

**2. Simulação das telas** (salve como `smoke.js` e rode com `node smoke.js`; estenda os dados de teste conforme a mudança)

```js
const fs=require('fs'),vm=require('vm');
const src=fs.readFileSync('/tmp/app.js','utf8');
const el=()=>({innerHTML:'',textContent:'',value:'',classList:{add(){},remove(){},toggle(){}},style:{},scrollIntoView(){}});
const sb={document:{querySelector:()=>el(),querySelectorAll:()=>[],addEventListener(){},activeElement:null,hidden:false,documentElement:{style:{setProperty(){}}},title:''},
 localStorage:{getItem(){return null},setItem(){}},location:{search:'?b=teste',hash:'',pathname:'/x/',origin:'https://u.github.io',href:'https://u.github.io/x/?b=teste'},
 history:{replaceState(){}},matchMedia:()=>({matches:false}),setInterval(){},clearTimeout,setTimeout,window:{},supabase:{},scrollTo(){},navigator:{},URLSearchParams,FormData,fetch,console};
const test=`
const out=[];const t=(n,f)=>{try{const r=f();out.push(n+': ok '+(typeof r==='string'?r.length:JSON.stringify(r)))}catch(e){out.push(n+': ERRO '+e.message)}};
S.b={id:'b1',slug:'teste',nome:'Brechó X',whats:'5511999999999',pix:'a@b.com',cidade:'São Paulo',reserva_min:30,retirada_ativa:true,entrega_local_ativa:true,envio_ativo:true,entrega_local_tabela:'Pinheiros: 10',envio_regioes:{SE:20},frete_gratis_acima:200};
S.pecas=[1,2,3,4,5,6].map(i=>({id:'p'+i,titulo:'Peça '+i,tam:'M',marca:'Farm',estado:'Ótimo',preco:50*i,categoria:'Vestidos',status:'disponivel',foto_url:'https://x/'+i+'.jpg',fotos:[],criado_em:new Date().toISOString()}));
t('loja',()=>lojaView());S.aba='entrega';t('entrega',()=>lojaView());S.aba='contato';t('contato',()=>lojaView());S.peca='p1';t('peça',()=>lojaView());S.peca=null;
S.modal={t:'reservar',id:'p1'};t('modal reservar',()=>modalHTML());S.modal=null;
t('frete',()=>calcFrete(S.b,100,'local','Pinheiros','SP'));
out.join('\\n')`;
console.log(vm.runInNewContext(src+'\n'+test,sb));
```

## Apêndice B: dados para uma loja de demonstração convincente

- 10 peças com fotos próprias e boas (nunca imagens copiadas), pelo menos 2 calçados, 1 bolsa e 5 roupas, com preços variados.
- Aba Loja: logo, capa, frase, aviso (por exemplo "Frete grátis acima de R$ 150"), Instagram, horário e texto "sobre".
- Aba Entrega: retirada com horários, entrega local com 2 ou 3 bairros e envio com valores por região; endereço protegido ligado.
- Fazer 1 reserva de teste, confirmar, avançar as etapas e deixar 1 depoimento, para mostrar o fluxo completo.

## Apêndice C: modelo de mensagem de abordagem (ainda não enviado)

> Oi! Vi que vocês reservam as peças por comentário e mensagem. Criei um link de loja onde a cliente reserva a peça sozinha, escolhe retirada ou entrega, paga por Pix e acompanha o pedido, e a peça some da vitrine na hora. Posso te mostrar em 30 segundos? O teste é grátis por 30 dias e eu cadastro as primeiras peças para você.

Enviar com o vídeo e o link da loja de demonstração, para 10 brechós do Instagram com 1 a 5 mil seguidores que já reservam por comentário.
