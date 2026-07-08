# Core AI V10 Evaluation Plan

Use this checklist to compare `src/AI-Core/ver9.py` and `src/AI-Core/ver10.py` on the same clips/camera scenes.

## Positive fall cases

- Forward fall from standing to floor.
- Side fall from standing to floor.
- Backward fall from standing to floor.
- Fall followed by no movement for at least 10 seconds.
- Fall followed by standing up within 3 seconds.

## False-positive challenge cases

- Person sleeping or resting on bed.
- Person lying on the floor before the camera starts.
- Sitting down quickly on a chair or sofa.
- Bending to pick up an object.
- Kneeling, stretching, yoga, or exercise on the floor.
- Camera angle low/oblique, person partly occluded.
- Dark room or strong backlight.
- Person far from camera.
- Two or more people crossing or occluding each other.
- Temporary stream drop/reconnect.

## Metrics

Track these per room/camera:

- True positives: actual falls that produce HIGH/CRITICAL.
- False positives: non-falls that produce HIGH/CRITICAL.
- False negatives: actual falls without HIGH/CRITICAL.
- Detection latency: seconds from floor impact to HIGH alert.
- Duplicate alerts: repeated alerts for the same incident within 60 seconds.

Recommended acceptance target for early field testing:

- False positives below 1 per 8 camera-hours.
- Detection latency below 5 seconds for high-risk rooms.
- No duplicate HIGH alerts for the same person/event inside cooldown.

## Suggested V10 test commands

Bedroom, conservative:

```bash
python src/AI-Core/ver10.py --input clips/test-household/sample.mp4 --room bedroom --score-threshold 65 --confirmation-limit 0 --sustained-score-frames 3
```

Bathroom, more responsive:

```bash
python src/AI-Core/ver10.py --input clips/test-household/sample.mp4 --room bathroom --score-threshold 60 --confirmation-limit 0 --sustained-score-frames 2
```

Debug a suspected false positive:

```bash
python src/AI-Core/ver10.py --input clips/test-household/suspect.mp4 --room living_room --score-threshold 70 --confirmation-limit 5 --alert-cooldown 60
```
