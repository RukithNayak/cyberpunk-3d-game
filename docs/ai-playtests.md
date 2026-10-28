# AI-05 Encounter Fixture

The fixture combines the accepted streamed two-chunk navigation encounter with
two lightweight ambient actors per area. The deterministic goon pursues and
backtracks across the district seam; ambient actors are children of their
streamed area and are released when the fixture retires those chunks. Ambient
pedestrians use the existing perception sound event and live faction standings.
They never submit dialogue or inference requests.

## Run the visual fixture

From the repository root:

```sh
godot --path game res://tests/scenes/encounter_fixture.tscn
```

The fixture automatically runs the seam route and displays the district/ambient
readout. Ambient status is shown over each blockout pedestrian as `CALM`,
`DISTRACTED`, or `ALERT`. The authored fixture emits a neutral player sound near
one pedestrian in each area to make distractions visible. Hostile sounds turn
the response into an alert using the current faction standing.

Press **F3** to show per-pedestrian ambient update counts, active population and
peak concurrent population. The update interval defaults to 0.75 seconds and
uses a timer instead of a per-frame callback; inactive actors stop that timer.
The focused `ai_encounter`
suite verifies a live faction change, sound radius, inactivity, real threaded
seam pursuit/backtracking and chunk-owned crowd cleanup:

```sh
godot --headless --path game --script res://tests/run_tests.gd -- --suite ai_encounter
```

The goon, crowd and district dressing are feasibility blockouts. This is not a
human encounter-balance or final character-art approval.
