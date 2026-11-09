# Sistema de FX — posicionamento e acompanhamento (A1)

Escopo: `SpawnedParticleDef`, `ParticleFX` e `ParticleInstance`. Tudo aqui é **visual e de
posição**. Nada toca em dano, hitbox, `HitBus`, `HitComponent`, `BossAction`, `FrameEvent`,
`FXChain*`, `Barrage*`, `DynamicFX` ou `StationaryFX`. Nenhum campo novo foi criado: a A1 faz
valer e completa campos que já existiam (`marker_path`, `offset`, `follow_marker`,
`mirror_marker_with_facing`). Nenhum `.tres` ou cena existente mudou.

## 1. O que mudou

1. **`offset` passou a valer** em `spawn_at` e `spawn_continuous` (antes era ignorado nesse
   caminho). Dá uma região relativa ao dono **sem criar `Marker2D`**.
2. **`follow_marker` foi completado**: antes só funcionava com `marker_path`, sobrescrevia a
   posição todo frame e perdia `position_variance`. Agora o FX acompanha o dono com ou sem
   marker, preserva o deslocamento do nascimento e re-espelha na virada do dono.
3. **`spawn_delay` só decide *quando* o FX aparece, não *onde***: para posições que dependem do
   dono, o FX nasce uma única vez, no instante em que o atraso termina, já no lugar certo
   (sem nascer em um ponto e ser corrigido depois).
4. **Rotação espelhada com o facing (opcional)**: `mirror_rotation_with_facing` faz o
   `inherit_facing` espelhar também a rotação da seção Transform (antes ele só virava a arte).
   `follow_updates_facing` re-espelha arte e rotação quando o dono vira com o FX vivo.

## 2. Como configurar (receitas)

| Caso | `marker_path` | `offset` | `follow_marker` | `mirror_marker_with_facing` | Observações |
|---|---|---|---|---|---|
| FX que acompanha o Boss (Shoryuken, FireKick) | vazio, ou um nó que já existe | região relativa ao pivô | true | true | Sem movimento próprio enquanto segue |
| Nasce relativo ao Boss e fica independente (corte de espada) | vazio | região | false | true | |
| Overlay (escudo de fogo do MeteorFall) | vazio ou `Sprite` | zero | true | opcional | `z_index` acima do sprite do Boss, `fade_out` desligado, `lifetime` ≈ duração da fase, animação em loop |
| FX com arte rotacionada que espelha com o lado (FireKick) | vazio | região | true | true | `inherit_facing` + `mirror_rotation_with_facing` (+ `follow_updates_facing` se o dono puder virar); `rotate_to_direction` **desligado** para um ângulo fixo; ângulo digitado para o lado da arte (direita) |
| FX com lógica própria (`FXChain`, Barrage, projéteis) | — | — | — | — | Não usar: seguem a própria lógica e não leem esses campos |

Os padrões reproduzem exatamente o comportamento anterior: um def que não mexe nesses campos
não muda em nada.

## 3. Convenções

- **Orientação nativa, por personagem.** O espelhamento usa `owner.get_facing_flip()`, que
  devolve -1 quando o dono olha para o lado oposto ao da arte *dele*. Marker e offset são
  autorados olhando a arte como ela foi desenhada. Nada no código assume a orientação do
  Magma Dragoon (arte à esquerda); chefes desenhados à direita funcionam do mesmo jeito.
- **Espelhar a posição ≠ espelhar a arte.** `mirror_marker_with_facing` espelha a *posição*
  (marker, offset e deslocamento do follow). `inherit_facing` espelha a *arte* (`flip_h`, que
  deve ser desenhada voltada para a direita) e a direção. São independentes.
- **Rotação espelhada.** Com `inherit_facing` + `mirror_rotation_with_facing`, o ângulo de
  `sprite_rotation_degrees` (e o de `rotate_to_direction`) é o do lado em que a arte "olha": a
  **direita**. Para o outro lado o sprite vira (`flip_h`) e o ângulo é invertido, dando a imagem
  espelhada exata (verificado numericamente em instâncias reais). `sprite_rotation_degrees` é
  **anti-horário** a partir da arte original: para uma arte desenhada para cima, 90 aponta para
  a esquerda, 130 para a esquerda e um pouco abaixo, 180 para baixo e 230 para a direita e um
  pouco abaixo (130 e 230 são imagens espelhadas uma da outra). Para um ângulo fixo, deixe
  `rotate_to_direction` desligado: ele soma o ângulo da direção (com `base_direction` vazio, a
  direção padrão é para cima) e o `spread_angle` sorteia ±15° por instância.
- **`owner = null` significa "posição já final".** Sem dono não há referência: o `offset` é
  ignorado. É a convenção que `_spawn_delayed` e as ondas já usavam, e o que impede o offset de
  ser somado duas vezes.
- **Dono sem `get_facing_flip()` (ex.: Player)** não espelha a posição; o FX continua sendo
  seguido normalmente.

## 4. Funções (o que faz, por que, onde, comportamento esperado)

### `ParticleFX.gd`

**`_resolve_pos(def, fallback, owner)`**
- O que faz: posição de nascimento = referência (o marker, se existir; senão a posição passada)
  + `def.offset` espelhado. Sem `owner`, devolve a posição passada como está.
- Por quê: o `offset` existia no Def mas nenhum caminho de ataque o aplicava.
- Onde: `spawn_at`, `spawn_continuous`, `_do_spawn`, `_spawn_delayed`, `_spawn_waves`.
- Esperado: o offset entra **uma única vez** por spawn, mesmo com atraso, onda ou burst.

**`_mirrored_offset`, `_facing_flip_for`**
- O que fazem: espelham o X do offset (e dos deslocamentos de follow) pela orientação nativa do
  dono. `_facing_flip_for` devolve +1 se a flag está desligada ou se o dono não tem
  `get_facing_flip()`.
- Por quê: um único ponto para a regra de espelhamento, usado pelo offset e pelo follow.

**`_is_owner_relative(def)`**
- O que faz: diz se a posição do def depende do dono (`marker_path`, `offset` ou `follow_marker`).
- Por quê: só esses defs passam a resolver a posição no fim do `spawn_delay`. Os demais
  continuam capturando a posição na chamada, como sempre.

**`_spawn_delayed`, `_spawn_waves`**
- O que fazem: para defs relativos ao dono, guardam o deslocamento do chamador e, quando o
  atraso termina, resolvem a posição a partir do dono *naquele instante*. Se o dono foi liberado
  durante o atraso, vale a posição de quando foi chamado.
- Por quê: evitar nascer em um ponto e ser corrigido depois (teleporte visual).
- Esperado: um único nascimento, no lugar final. Ondas continuam nascendo sempre do mesmo ponto.

**`_spawn_burst_delayed`**
- O que faz: com `follow_marker`, cada passo do burst nasce na referência *atual* do dono + o
  mesmo deslocamento do primeiro passo.
- Por quê: antes só o marker era re-lido a cada passo; sem marker, os passos seguintes
  repetiriam a posição inicial em vez de acompanhar o dono.

**`find_follow_marker`, `follow_reference`, `follow_delta_native`, `follow_point`** (públicas)
- O que fazem: o ponto único de resolução do follow. Escolhem a referência (marker ou pivô do
  dono), calculam o deslocamento em orientação nativa e reconstroem a posição re-espelhada.
- Por quê: o `ParticleInstance` e os passos do burst precisam calcular exatamente a mesma coisa.
- Esperado: deslocamento constante em relação ao dono, preservando `position_variance`.

### `ParticleInstance.gd`

**`setup` (trecho do follow)**
- Guarda a referência (o marker, se existir) e o deslocamento do FX em relação a ela na
  orientação nativa. Esse deslocamento já inclui `offset`, `position_variance` e qualquer
  deslocamento do chamador.

**`_update_follow` (chamada em `_process`)**
- A cada frame: `global_position = referência atual + deslocamento re-espelhado`. Uma virada
  do dono vale no mesmo frame. Se o dono ou o marker forem liberados, para de seguir e o FX
  termina normalmente (fade e lifetime).
- Enquanto segue, não há movimento próprio (`velocity` e `gravity` ignoradas), como já era.

**`ParticleInstance._apply_facing(facing_right)`** e o trecho do `setup` que o prepara
- O que faz: aplica o facing à arte: `flip_h` quando o dono olha para a esquerda (arte desenhada
  para a direita) e, com `mirror_rotation_with_facing`, inverte o ângulo junto. No `setup`, a
  direção (já espelhada em X por `ParticleFX._resolve_direction`) é desfeita para obter a rotação
  "voltado para a direita".
- Por quê: o `inherit_facing` só virava a arte e a rotação ficava igual nos dois lados, então
  uma arte rotacionada nunca era a imagem espelhada da outra.
- Onde: `setup` (nascimento) e `_update_follow` (se `follow_updates_facing` e o dono virou).
- Esperado: flags desligados = comportamento de sempre. O flag de rotação só age com
  `inherit_facing`; `follow_updates_facing` só age com `follow_marker` e `inherit_facing`.

## 5. Compatibilidade

- Os defs que usam `SpawnedParticleDef` hoje são o preamble do MeteorFall, a explosão da
  derrota do Magma Dragoon, `dash_smoke`, `dash_spark` e os efeitos de morte de X e Zero. Só o
  `dash_smoke_def` tem `offset ≠ 0`, e ele vai por `create_spawner` → `FXSpawner` →
  `spawn_at_resolved`, caminho que não mudou.
  `create_spawner` **não** aplica `def.offset`: quem chama o usa como posição local do spawner.
- Nenhum def do jogo usa `follow_marker = true` hoje.
- `spawn_at_resolved`, `spawn_exact`, `FXSpawner`, `FXComponent`, `FXChain*` e `Barrage*`
  não foram alterados.

## 6. Efeitos colaterais conhecidos

- Um def com posição relativa ao dono **e** `spawn_delay` passou a manter o dono ao fim do
  atraso. Por isso esses FX agora respeitam `inherit_facing` na direção e `require_grounded`,
  como os FX sem atraso (antes o dono era descartado no atraso e esses dois eram ignorados).
  Nenhum def atual combina as duas coisas.
- A arte e a rotação (`inherit_facing`) são decididas no nascimento: se o dono virar com o FX
  vivo, a posição re-espelha, mas a arte e a rotação só acompanham com `follow_updates_facing`.
- `offset` e marker são estáticos em relação ao pivô: não acompanham um membro que muda de
  lugar entre frames da animação (ex.: o punho no Shoryuken). Isso exigiria marker animado ou
  âncoras por frame.

## 7. Validação realizada

- Harness temporário no Godot 4.6: **15 cenários de regressão** comparados a um baseline da
  lógica original (diff vazio) e **66 asserts** do comportamento novo (orientação nativa à
  esquerda e à direita, virada no meio da vida, `spawn_delay`, ondas, burst com intervalo,
  variance, dono e marker liberados, etc.). Resultado igual no sandbox e no projeto local.
- Rotação espelhada: 87 asserts no total (21 novos), 15 de regressão com diff vazio, 5 mutações
  detectadas (ângulo sem inverter, follow sem re-espelhar, flag ignorando `follow_updates_facing`
  ou `inherit_facing`, direção espelhada não desfeita) e execução estável de 20 a 144 fps.
- Testes de mutação (offset somado em dobro na onda e no burst, re-espelhamento removido,
  deslocamento zerado no `setup`, follow desligado nos passos do burst, marker ignorado):
  todos detectados pelos testes certos. Execução estável de 20 a 144 fps.
- Em jogo: luta do Magma Dragoon e Dash de X e Zero visualmente inalterados.
- O harness foi removido do projeto junto com o gancho de log do `ParticleInstance`. Para
  reativá-lo (ex.: ao mexer de novo em `ParticleFX`): restaure `_a1_validation/A1Baseline.gd` e
  coloque, no fim de `ParticleInstance.setup()`:

```gdscript
if Engine.has_meta(&"a1_spawn_log"):
	var _a1_log: Callable = Engine.get_meta(&"a1_spawn_log")
	_a1_log.call(self, def, owner)
```

## 8. Registro para etapas futuras (fora do escopo da A1)

- **`FXChain`**: o atraso de nascimento deveria ser apenas visual. Hoje, com `spawn_delay`, um
  segmento pode nascer na posição do dono e depois ser reposicionado para seguir a cabeça da
  cadeia, o que causa um teleporte visual. Não foi alterado. Se os segmentos ganharem hitbox
  opcional, ela precisará usar exatamente a mesma posição e transformação do segmento visual
  (uma única fonte de verdade, como `_altura` no `PillarHazard`): o jogador nunca pode receber
  dano de uma hitbox em lugar diferente de onde o FX aparece.
- **Hitbox em FX (A3)**: sendo filha do `ParticleInstance`, a hitbox acompanha o follow sem
  código extra.
- **`FrameEvent`**: decisão tomada — `particle_def` é só para `SpawnedParticleDef` (o nome é
  histórico, não é obsoleto) e `fx_resource` é para Defs com lógica própria (`FXChainDef`,
  `BarrageDef`), sem suporte a `SpawnedParticleDef`; só os tooltips foram atualizados. Renomear
  a *variável* `fx_resource` quebraria os dados gravados em 4 recursos (`FlameAttack_AttackPattern`,
  `MeteorFall_AnimPhase`, `MagmaDragoonHadouken` e `MagmaDragoonHadouken2`), por isso não foi feito.
