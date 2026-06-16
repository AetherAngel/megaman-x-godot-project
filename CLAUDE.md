# CLAUDE.md — Contexto de Trabalho com Claude

> Este arquivo é lido por Claude no início de cada conversa.
> Última atualização: 2026-06-16

---

## 1. Quem é o usuário

- **Nome:** Daniel (AetherAngel)
- **Perfil:** Dev Jr. autodidata — 6 anos de programação, 3 anos utilizando IA como ferramenta.
- **Nível:** Entende lógica, fundamentos e OOP. Fica confuso em conceitos avançados rapidamente.
- **Linguagem preferida:** Português brasileiro.
- **Projeto principal:** MMX — jogo inspirado em Mega Man X4, desenvolvido em Godot Engine com GDScript.
- **Repositório:** https://github.com/AetherAngel/megaman-x-godot-project

---

## 2. Como Claude deve trabalhar com o usuário

### 2.1 Regras de código

1. Sempre que criar ou modificar uma função, documentar o raciocínio em um `README.md` explicando: o que a função faz, por que foi necessária, onde é aplicada e qual comportamento esperado ela gera.
2. Nunca tirar algo de contexto. Se precisar de contexto adicional, perguntar antes de agir.
3. Utilizar apenas o contexto da tarefa atual. Não vasculhar o projeto inteiro ou toda a conversa para pegar contexto que não foi pedido — isso gera lixo na resposta.
4. Nunca criar variáveis, funções ou seções de código que não condizem com o contexto atual da tarefa.
5. Nunca entregar código sem explicar o que foi feito — sempre via README (regra 1), nunca na resposta direta.
6. Antes de finalizar qualquer código, fazer LogicCheck (ver seção 2.3).
7. Se o pedido ficou confuso, solicitar um relatório técnico preenchível pelo usuário — sem suposições.
8. Nunca enviar código sem testar a lógica antes.
9. "Testar" não significa compilar manualmente — significa fazer LogicCheck em toda função modificada e onde ela é aplicada.
10. Ao realizar a adição de um novo autoload verificar se ele exporta variavéis, se sim, deixar claro ao usuário para não criar um gd e sim um tscn para carregar como cena vazia.

### 2.2 Regras de comunicação

- Tratar o usuário como Dev Jr.: explicar conceitos sem ser condescendente, mas sem pular etapas.
- Não tomar a hipótese do usuário como absoluta — verificar se faz sentido lógico antes de implementar.
- Nunca excluir ou pedir para descartar algo e logo depois gerar código que dependia disso.
- Não gerar respostas baseadas no que o usuário disse quando o erro foi de Claude — ser independente e objetivo.

### 2.3 LogicCheck (obrigatório após qualquer mudança)

Responder internamente a estas perguntas antes de entregar qualquer código:

- A função que criei/modifiquei/excluí pode impactar outra parte do projeto? Onde?
- Alguma outra parte do projeto dependia disso? É possível fazer sem interferir?
- Não consigo sem interferir? Então refatorar — mas refatorar vai quebrar alguma diretriz?
- Não quebra nenhuma diretriz? Então refatorar, com cuidado ao que o usuário fazia ali.
- Estou hardcodando algo que não deveria? Evitar quando possível.
- O que criei vai gerar o comportamento que o usuário esperava? Se não, informar antes de entregar.
- Nunca pedir para descartar algo e depois gerar código que depende disso.

---

## 3. Regras de planejamento e entrega

- **Sempre planejar o próximo passo** (pequeno ou grande) antes de executar, para evitar bugs e comportamentos inesperados.
- **Mudanças complexas:** oferecer um canvas visual para o usuário entender o que vai ser feito antes de começar.
- **Mudanças grandes:** dividir em batches e aplicar LogicCheck em cada um.
- **README.md:** gerar apenas ao final de todo o progresso de uma tarefa — nunca no meio.

---

## 3.1 Fase de Planejamento (obrigatória antes de qualquer código)

Antes de escrever qualquer linha de código, Claude deve executar esta fase na ordem abaixo.

### Princípios que correm durante toda a fase
- Código limpo e legível
- Código profissional e de alto nível
- Sistema desacoplado — cada parte com seu papel, sem dependências desnecessárias
- Evitar hardcode sempre que possível

### Etapas

**1. Definição**
Qual é o problema? O que precisa ser feito? Qual é o comportamento esperado ao final?
Sem definição clara, não avança.

**2. Padrão (Design Pattern / Code Pattern)**
Qual padrão será usado? Por que esse e não outro?
Justificar a escolha no início para manter consistência durante toda a construção.

**3. Arquitetura**
Quais são os sistemas/módulos envolvidos? Qual é a responsabilidade de cada um?
Cada parte deve ter um papel único e bem definido.

**4. Dependências e Riscos**
O que depende do quê? Onde estão os pontos de risco?
Mapear antes de construir para não gerar surpresas no meio do caminho.

**5. Contratos de Interface**
Como os sistemas se comunicam entre si? (signals, funções públicas, eventos, etc.)
Definir as "bordas" de cada módulo antes de implementar o interior.

**6. Análise do Conjunto**
O plano todo é coerente? Existe algum conflito entre os módulos?
Verificar se as etapas 1 a 5 fazem sentido juntas.

**7. Canvas de Visão Geral**
Apresentar um canvas visual com tudo que foi planejado.
→ Apresentado **somente no final da fase de planejamento**, não no final da resposta.
→ Após o canvas, aguardar aprovação do usuário antes de começar a implementar.

---

## 4. Contexto do projeto MMX

- **Engine:** Godot Engine (GDScript)
- **Inspiração:** Mega Man X4
- **Arquitetura:** Modular, desacoplada, orientada a dados (Data-Driven)
- **Status:** Em desenvolvimento ativo
- **Repositório:** https://github.com/AetherAngel/megaman-x-godot-project

### Estrutura de pastas

```
megaman-x-godot-project/
├── Menus/              # Telas de menu (stage select, character select)
├── autoload/           # Singletons/Autoloads globais (GameManager, SoundManager, etc.)
├── enemies/
│   └── boss/           # Lógica e cenas de boss battles
├── interactable/
│   └── objects/        # Objetos interagíveis do cenário
├── levels/             # Cenas de fase/level
├── particlesystem/     # Sistema de partículas customizado e reutilizável
├── player/             # Sistemas do jogador (movimento, dash, tiro, combo, armadura)
├── resources/          # Resources (.tres/.res) — dados do jogo
├── systems/            # Sistemas gerais desacoplados (combat, health, FX, etc.)
├── talksystem/         # Sistema de diálogo/falas
└── ui/
    └── debug/          # UI de debug em desenvolvimento
```

### Sistemas implementados

**Gameplay:** movimento de X, dash, tiro, combo, boss battle, armadura, stage select, character select, health/combat.

**Técnicos:** particle system customizado, layered sprite rendering, GameManager, SoundManager global, state-based logic, sistemas reutilizáveis de FX.

---

## 5. Como usar este arquivo

No início de cada conversa nova, o usuário compartilha este link:

```
https://raw.githubusercontent.com/AetherAngel/megaman-x-godot-project/main/CLAUDE.md
```

Claude deve buscar este arquivo, ler, e confirmar com:

> "Contexto carregado, parceiro. Pode começar."

Nenhuma outra resposta é necessária além dessa confirmação.
