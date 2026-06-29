# Mega Man X Inspired Prototype

Gameplay/combat prototype inspired by Mega Man X, developed in Godot using a modular and scalable architecture.

The project was built as a large-scale gameplay and systems study, focusing on reusable systems, combat orchestration, visual layering, and structured game architecture. Over the course of development, the scope expanded from a basic movement/combat prototype into a fully decoupled, data-driven framework covering health, damage, character management, AI, and HUD systems — built with an explicit focus on scalability for future content (new characters, bosses, and weapons) without rewriting existing code.

## Features

### Gameplay Systems

* X and Zero movement systems (dash, air dash, wall kick, hover, Nova Strike)
* Buster shooting system with charge levels (stock/plasma charge types)
* Saber combo attack system, fully data-driven via attack resources
* Technique system — ground, air, dash and wall techniques per armor (e.g. Zero's elemental saber arts), with unlock-gated progression
* Special weapon system — X's boss-reward weapons, each with its own ammo pool and elemental type
* Mid-stage character switching (X / Zero), with fully independent HP per character
* Universal health system shared by player, bosses, and common enemies
* Elemental damage and resistance system — per-boss weaknesses, immunities, and multi-segment health bars (Mega Man Zero–style)
* Boss battle system driven by a custom Behavior Tree AI framework, supporting multi-phase fights and frame-accurate attack choreography
* Armor system, capability-driven (no hardcoded character checks)
* Stage select
* Character select
* Health and combat management

### Technical Systems

* Universal HP architecture (`HPSystem` / `DamageHandler` / `HealHandler`), fully decoupled from entity type — the same system powers the player, bosses, and regular enemies
* Elemental damage resolution pipeline (damage types, per-boss resistance tables, weakness/immunity resolution)
* Custom Behavior Tree framework for boss and NPC AI — composable, reusable subtrees, per-instance state isolation (no shared state between boss encounters)
* Frame-accurate boss action system — multi-phase animations with data-driven exit conditions and per-frame hitbox/FX/SFX events, with no placeholder "ghost" states
* Character management and persistence system — roster-driven character switching with independent HP snapshots preserved per character across switches
* Data-driven HUD / HP bar rendering — pixel-accurate positioning, configurable orientation (vertical or horizontal bar styles)
* Combat lock system — state-gated damage windows (e.g. disabled during boss intros/presentations, enabled only during active combat)
* Resource warmup / loading pipeline — task-based startup sequence that eliminates first-use frame stutter
* Custom particle system
* Layered sprite rendering system
* Modular gameplay architecture
* Decoupled managers and systems
* GameManager orchestration (state machine–driven flow)
* Global SoundManager
* Data-driven organization throughout
* Reusable FX systems
* State-based gameplay logic

## Technologies

* Godot Engine
* GDScript
* Modular Architecture
* Data-Driven Design
* Object-Oriented Programming
* Finite State Machines
* Behavior Trees (custom implementation)

## Development Notes

This project was developed with the assistance of generative AI as an engineering support tool for:

* Prototyping
* Debugging
* System iteration
* Debugging assistance
* Workflow acceleration

All software architecture, system design, implementation strategy, integration, and technical decisions were designed and directed by the project author.

## Media Credits

### Music / Remixes

* Mega SFC
* Dracula9AntiChapel (Magma Dragoon remixes)

### Sprites / Visual Assets

* MegaMan-X-Engine
* Fourth Armor sprite by Samuel Higino and Darksamu993

This is a non-profit fan game. All rights to the original franchise, characters, music, and related assets belong to CAPCOM.

## Project Goal

The primary goal of this project was to study:

* Combat architecture
* Gameplay scalability
* Decoupled systems
* Reusable gameplay components
* Manager orchestration
* Structured game development pipelines
* AI-driven boss/NPC behavior design
* Elemental combat systems
* Data-driven UI architecture

What started as a movement/combat prototype has since grown into a broader Mega Man X4–inspired demake, with systems designed to scale toward a full roster of playable characters, bosses, and weapons.
