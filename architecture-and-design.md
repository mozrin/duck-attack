# Duck Attack architecture and design document

A playful, fast-paced homage to Missile Command—except the “missiles” are breadcrumbs, the “aliens” are hungry ducks, and the launcher is a grandma on a park bench. The core loop blends precision shots with predictive “breadcrumb tosses” that lure ducks off-path to eat. If ducks swarm the bench—game over.

---

## Game overview and concept

- **Core fantasy:** Protect Grandma by feeding ducks strategically—either hit them or bait them.
- **Loop:** Aim → fire breadcrumb → manage cooldowns → place lures → control crowd flow → survive waves.
- **Win/lose:** Survive all waves in a level to win; if a duck touches Grandma or a swarm threshold is exceeded, you lose.
- **Camera & controls:** Top-down or slightly isometric. Single-touch drag to aim; tap to fire; long-press to “lob” a breadcrumb lure with adjustable arc.
- **Session length:** 2–4 minutes per level; escalating difficulty via duck speed, flock size, and special behaviors.

---

## Mechanics and rules

### Entities

- **Grandma (player base):**
  - **Health:** 1 (touch = lose) or a small buffer (e.g., 3 hits).
  - **Cooldowns:** Breadcrumb shot cooldown \(\approx 0.6\)–\(1.0\) s; lure toss cooldown \(\approx 2.0\)–\(3.0\) s.
  - **Aim cone:** Slight spread for “shot” mode; parabolic arc for “lure” mode.

- **Breadcrumbs:**
  - **Shot breadcrumb:** Fast projectile; on hit, ducks are “fed” and slow briefly, then resume pathing.
  - **Lure breadcrumb:** Stationary pickup; ducks within radius \(\,r_l\) re-target to the lure, eat for \(\,t_e\) seconds, then resume.

- **Ducks (AI agents):**
  - **States:** SeekBench → SeekLure → Eat → Flee (optional) → Disperse (between waves).
  - **Attributes:** Speed, hunger, attention span, flock role (leader/scout/follower), aggression.

- **Waves:**
  - **Composition:** Spawn points around the map; mix of roles and speeds.
  - **Escalation:** More ducks, tighter spawn intervals, smarter leaders, shorter attention spans.

### Key rules

- **Swarm loss:** If \(\geq N_s\) ducks enter Grandma’s proximity radius \(\,r_g\), instant loss.
- **Collision:** Duck touching Grandma = loss (unless buffer health).
- **Lure priority:** Ducks evaluate lure utility vs. bench utility; closer, fresher lures win.
- **Eating lock:** While eating, ducks ignore shots unless “panic” is triggered by nearby impacts.

---

## AI agent behavior and decision-making

### Approach

Use a hybrid of **Utility AI** (for target selection), **Behavior Trees** (for action sequencing), and **Flocking/Steering** (for movement). This keeps decisions explainable, tunable, and performant.

#### Utility scoring

- **Bench utility \(U_b\):**
  \[
  U_b = w_d \cdot \frac{1}{d} + w_a \cdot A + w_s \cdot S
  \]
  - \(d\): distance to bench; \(A\): aggression; \(S\): swarm bonus when many ducks are near.

- **Lure utility \(U_l\):**
  \[
  U_l = w_{ld} \cdot \frac{1}{d_l} + w_{lf} \cdot F + w_{lt} \cdot T - w_{lc} \cdot C
  \]
  - \(d_l\): distance to lure; \(F\): freshness; \(T\): time remaining; \(C\): crowding at lure.

- **Decision:** If \(U_l > U_b + \Delta\), switch to SeekLure; else SeekBench.

#### Behavior tree (per duck)

- **Root**
  - **Check panic:** If recent impact within radius → Flee (short burst).
  - **Evaluate targets:** Utility compare bench vs. nearest lure.
  - **If SeekLure:** Move via steering to lure; on arrival → Eat for \(\,t_e\).
  - **Else SeekBench:** Move via steering to bench; if within \(\,r_g\) → trigger swarm/lose.
  - **Post-eat:** Re-evaluate; likely SeekBench unless new lure wins.

#### Movement: steering + flocking

- **Steering:** Seek(target), Avoid(obstacles), Arrive(slowdown near target).
- **Flocking:** Cohesion, Alignment, Separation with tunable weights per role.
- **Leader/follower:** Leaders sample utility more frequently; followers bias toward leader’s target.

#### Attention & memory

- **Attention span:** Decays over time; ducks may abandon distant lures.
- **Short-term memory:** Avoid re-targeting a recently consumed lure for \(\,t_m\).

---

## Game architecture and data flow

### High-level component map

| Component | Responsibility | Tech |
|---|---|---|
| **GameCore** | Main loop, tick scheduling, scene orchestration | Flutter + Flame |
| **ECS/Entities** | Grandma, Ducks, Breadcrumbs, Lures | Flame components or lightweight ECS |
| **AI System** | Utility scoring, behavior trees, steering | Pure Dart modules |
| **Physics System** | Projectile motion, collisions, proximity checks | Flame/Forge2D (optional) |
| **Input System** | Touch gestures, aim modes, cooldown gating | Flutter GestureDetector |
| **Rendering** | Sprites, particles, UI overlays | Flame Sprite/Particle |
| **Audio** | Quacks, toss, hit, eat loops | Flame Audio |
| **Wave Director** | Spawns, difficulty scaling, pacing | Dart service |
| **State & Save** | Settings, progress, difficulty | Riverpod/Bloc + shared_prefs |
| **Platform Layer** | iOS/Android configs, haptics, permissions | Platform channels (minimal) |

### Data flow (tick-level)

1. **Input → Command:** Gesture updates aim vector; tap/long-press emits Shot or Lure command.
2. **Command → Entities:** Create breadcrumb projectile or lure entity; start cooldown timers.
3. **AI System:** For each duck, compute utilities, update behavior state, produce steering vector.
4. **Physics:** Integrate positions; resolve collisions (duck–breadcrumb, duck–lure, duck–bench).
5. **Wave Director:** Check thresholds; spawn next ducks; adjust difficulty.
6. **Rendering:** Draw entities; UI shows cooldowns, wave progress, swarm meter.
7. **Audio/Haptics:** Trigger events (hit, eat, panic, swarm warning).

---

## Implementation details in Flutter and Dart

### Framework & packages

- **Engine:** Flame (2.x) for game loop, components, particles.
- **Optional physics:** Forge2D if you want true collision bodies; otherwise custom proximity checks.
- **State:** Riverpod for DI and reactive state; ValueNotifier for micro-optimizations.
- **Assets:** Sprite sheets (grandma, ducks), particle effects (crumb dust), audio (quacks, toss).
- **Build:** Flutter stable; Android minSdk ~23; iOS 13+.

### Project structure

```
lib/
  main.dart
  game/
    duck_attack_game.dart        // Flame Game subclass
    components/
      grandma.dart
      duck.dart
      breadcrumb_shot.dart
      breadcrumb_lure.dart
    systems/
      ai/
        utility.dart
        behavior_tree.dart
        steering.dart
        flocking.dart
      physics/
        collisions.dart
        integrator.dart
      wave/
        wave_director.dart
    ui/
      hud.dart
      pause_menu.dart
  core/
    config.dart
    assets.dart
    audio.dart
    input.dart
    services/
      save_service.dart
      analytics_stub.dart
```

### Key classes (sketch)

- **DuckComponent**
  - **Fields:** position, velocity, role, hunger, attention, state, targetRef.
  - **Update:** `evaluateUtility()`, `tickBehaviorTree()`, `applySteering()`.
- **BreadcrumbShotComponent**
  - **Fields:** origin, velocity, damage=0, feedEffect=slowdown.
  - **Collision:** on hit → duck enters brief “fed” slow state.
- **BreadcrumbLureComponent**
  - **Fields:** position, freshness, timeToExpire, capacity.
  - **Effect:** ducks within \(\,r_l\) re-target; eating locks them for \(\,t_e\).
- **WaveDirector**
  - **Config:** waves[], spawnPoints[], difficulty curve.
  - **Logic:** spawn schedule, role mix, attention/aggression scaling.

### Pseudocode: duck decision tick

```dart
void DuckAI.update(double dt) {
  if (panic.inEffect) { state = DuckState.flee; steer = Steering.flee(panic.source); }
  else {
    final benchU = Utility.bench(distanceToBench, aggression, swarmFactor);
    final lure = LureRegistry.bestFor(position);
    final lureU = lure != null ? Utility.lure(distanceTo(lure), lure.freshness, lure.timeLeft, lure.crowding) : 0;

    if (lureU > benchU + config.utilityDelta) {
      state = DuckState.seekLure;
      target = lure.position;
    } else {
      state = DuckState.seekBench;
      target = bench.position;
    }
    steer = Steering.seek(target)
      + Steering.separation(neighbors)
      + Steering.cohesion(neighbors)
      + Steering.alignment(neighbors)
      + Steering.avoid(obstacles);
  }

  velocity = Integrator.apply(velocity, steer, dt, maxSpeed);
  position += velocity * dt;

  if (near(lure) && state == DuckState.seekLure) { state = DuckState.eat; eatTimer.start(); }
  if (eatTimer.done) { state = DuckState.idle; attention.reset(); }
}
```

### Input & firing modes

- **Shot mode (tap):**
  - **Aim:** drag to set direction; tap to fire straight breadcrumb.
  - **Cooldown:** short; shows radial meter on HUD.

- **Lure mode (long-press):**
  - **Arc:** hold to set power; release to lob; preview trajectory.
  - **Cooldown:** longer; HUD meter distinct color.

### Performance notes

- **Batching:** Use Flame’s component batching; avoid per-frame allocations.
- **Spatial partitioning:** Uniform grid or quadtree for neighbor queries (flocking, lure radius).
- **Fixed timestep:** Semi-fixed update \(\Delta t\) for deterministic AI; render interpolated.
- **Mobile tuning:** Cap ducks per wave; LOD for sprites; limit particle counts.

---

## Platform-specific considerations

- **Android:**
  - **Haptics:** Light vibration on swarm warning and successful lure placement.
  - **Performance:** Test on mid-range devices; enable Skia tracing during dev.

- **iOS:**
  - **Haptics:** Use Core Haptics via Flutter plugin for subtle feedback.
  - **App lifecycle:** Pause game on interruptions; ensure audio session category fits.

- **Shared:**
  - **Safe area & aspect:** Adaptive UI for notches; letterbox if needed.
  - **Frame pacing:** 60 FPS target; gracefully degrade to 30 FPS under load.
  - **Privacy:** No network permissions by default; offline-first.

---

## Tuning, difficulty, and content pipeline

- **Difficulty curve:**
  - **Early:** Slow ducks, generous lure attention, low aggression.
  - **Mid:** Faster leaders, shorter attention, more spawn points.
