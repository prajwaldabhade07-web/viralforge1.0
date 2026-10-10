# Scoring, moderation and safety

## Rubric
The model rates **seven dimensions** as integers 1 to 10: hook strength, clarity, emotional appeal, entertainment
value, information value, audience retention potential, shareability. Anchors: 1-2 very weak, 3-4 weak, 5-6 average
for the platform, 7-8 strong, 9-10 exceptional (used rarely). The model is told **not** to compute any totals.

The backend (`app/services/scoring.py`) derives the five report scores (0 to 100, **round half up**, using `Decimal`):

| Score | Formula |
|---|---|
| Hook | Hook strength × 10 |
| Engagement | mean(clarity, emotional appeal, entertainment, information) × 10 |
| Retention | Audience retention potential × 10 |
| Shareability | Shareability × 10 |
| Overall | 0.30 Hook + 0.25 Engagement + 0.25 Retention + 0.20 Shareability, computed from the **displayed (rounded)** scores so anyone can reproduce it |

Verdict bands: 90+ Exceptional, 75+ Strong, 60+ Promising, 40+ Developing, below 40 Needs rework.
Out-of-range or missing ratings are rejected (the model gets one repair retry; then the job fails with `ai_response_invalid`).
Any score fields a model might add are ignored.

## Personas
Ten fixed personas (fast scroller, busy parent, niche enthusiast, sceptic, sound-off commuter, small business owner,
college student, 60+ viewer, aspiring creator, non-native-English viewer). They react to the model's **text summary**
of the video, not to the video itself, which keeps cost low. If some are missing, one targeted retry is made; results are labelled
`complete`, `partial` or `failed`, missing personas are shown as such, and a persona failure never fails the report.
They are always labelled AI-simulated.

## Moderation policy
Blocked: sexual content or any sexualisation of minors; explicit sexual content; shock gore; violent extremism or
incitement; hate or harassment of protected groups; promotion of self-harm; serious illegal activity; weapons
manufacture or drug sales; scams; doxxing. Allowed: ordinary edgy humour, mild profanity, news and education on sensitive topics.
The check runs on the same uploaded file before the analysis call, **fails closed**, and on a block deletes the video
and clears caption and script.

## Prompt-injection defences
Untrusted text is control-character stripped, length-capped, wrapped in per-request random delimiters the user cannot
close, and the system prompts state that anything inside (and any speech or on-screen text in the video) is data.
Suspected injection phrases are logged by job id only (never content). Scores are computed in code.
