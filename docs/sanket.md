# Sanket's Viva Guide — ViralForge AI Engineering
## Ready-to-speak explanations, AI pipeline, file guide, and technical questions

## 1. What does the AI part of ViralForge do?

**Ready answer:**  
“ViralForge helps creators evaluate short-form videos before publishing them. The AI subsystem analyzes content and produces structured ratings and explanations. The backend validates those results and calculates the final scores. The system also generates simulated reactions from different viewer personas. These outputs help creators identify possible improvements, but they do not guarantee that a video will go viral.”

## 2. Technologies in plain English

| Technology | Simple meaning | Role |
|---|---|---|
| Google Gemini | Generative AI models | Generates content assessments and explanations |
| `google-genai` SDK | Library for calling Google's AI services | Lets backend code send requests and handle responses |
| Gemini Files API | Media file interface for supported model workflows | Used in the documented video-analysis path |
| FastAPI | Python backend framework | Coordinates requests, jobs, services, and results |
| Pydantic | Data validation/schema library | Checks whether data has the expected structure |
| Scoring service | Ordinary backend code | Calculates final scores from validated ratings |
| Background worker | Component that processes queued jobs | Runs analysis without making the initial request wait for everything |

The model is configured through the `GEMINI_MODEL` setting. The model name must be available to the configured API key; the readiness check is the appropriate place to confirm model access.

## 3. How the AI pipeline works

1. The user submits a video and its context.
2. The backend validates the request and creates an analysis job.
3. A background worker claims the job.
4. A moderation/safety check runs before the main analysis.
5. The backend prepares the video and sends it through the Gemini workflow.
6. Gemini returns ratings and explanations for seven dimensions.
7. A persona-simulation stage generates possible reactions from ten predefined viewer types.
8. The backend validates the model response.
9. Deterministic scoring code calculates the final five report scores.
10. The report is saved, and the job is marked completed or failed.
11. The frontend retrieves the status and displays the report.

**Ready answer:**  
“The AI pipeline is more than one model call. The backend validates the request, runs safety checks, sends the video to Gemini, validates the response, runs persona simulation, calculates the scores, and saves the report. The job is processed asynchronously so the user can check progress.”

## 4. What the important AI-related files and folders do

The repository's visible top-level areas include `backend/` and `docs/`. The public documentation identifies `backend/app/services/scoring.py` as the scoring service. The current exact paths of the model gateway, prompt definitions, schemas, and worker should be read from the actual repository rather than guessed.

| File or area | Simple explanation | Technical explanation |
|---|---|---|
| `backend/` | Contains server-side application logic | Includes API routes, schemas, services, configuration, and background processing |
| `backend/app/services/scoring.py` | Calculates the final report scores | Applies deterministic formulas and rounding to validated ratings |
| AI/model gateway module | Communicates with Gemini | Handles client configuration, model requests, responses, and provider errors; find its exact path in the source |
| Prompt/template module | Defines what the model is asked to do | Sets the task, output expectations, and instructions for treating user content as untrusted |
| Analysis pipeline/worker | Coordinates the analysis stages | Manages job state, safety checks, media preparation, model calls, scoring, and persistence |
| AI response schema | Defines a valid model response | Validates required fields and numeric rating ranges |
| `docs/SCORING.md` | Explains scoring and safety design | Describes ratings, formulas, moderation, personas, and prompt-injection defenses |
| `docs/API.md` | Explains how the API behaves | Describes job states, response structures, and how results are retrieved |
| `docs/VERIFICATION.md` | Records what has and has not been verified | Separates tests run with substitutes from live external integrations |
| `.env.example` | Lists configuration names safely | Shows expected variables without revealing actual credentials |

## 5. Model-generated judgment versus normal code

### What Gemini does
Gemini generates content assessments, ratings, and explanation text. These are model outputs and can vary or be wrong.

### What the backend does
The backend validates the output, handles job state, saves the report, and calculates final scores using fixed formulas. The documented design tells the model not to calculate the final totals.

### Why this separation matters
If score arithmetic is handled by deterministic code, the same validated ratings produce the same scores. This makes the result easier to test and reproduce than trusting a model-generated total.

### Persona simulation
The system generates reactions from ten predefined viewer types, such as a fast scroller, busy parent, niche enthusiast, sceptic, sound-off commuter, small-business owner, college student, older viewer, aspiring creator, and non-native-English viewer.

These are **simulated reactions, not real survey participants**. The documented workflow uses a text summary for the persona step. They are useful as possible perspectives, not proof of how actual viewers will behave.

## 6. The scoring system

The model rates seven dimensions from 1 to 10:
- Hook strength
- Clarity
- Emotional appeal
- Entertainment value
- Information value
- Audience-retention potential
- Shareability

The backend calculates five report scores:

| Score | Formula |
|---|---|
| Hook | Hook strength × 10 |
| Engagement | Average of clarity, emotional appeal, entertainment value, and information value × 10 |
| Retention | Audience-retention potential × 10 |
| Shareability | Shareability × 10 |
| Overall | 30% hook + 25% engagement + 25% retention + 20% shareability |

The documented implementation uses decimal arithmetic and half-up rounding. It calculates the overall score from the displayed rounded component scores. Verdict bands are 90+ Exceptional, 75+ Strong, 60+ Promising, 40+ Developing, and below 40 Needs rework.

**Ready answer:**  
“Gemini provides the seven detailed ratings. The backend validates them and applies fixed formulas to calculate the five final scores. The score is a product-defined rubric, not a scientifically proven prediction of virality.”

## 7. Prompt injection and content safety

Prompt injection occurs when untrusted content attempts to manipulate the model's instructions. In a video-analysis application, that content could appear in a caption, script, spoken audio, or text shown in a video.

The documented defenses include sanitizing and limiting untrusted text, using per-request delimiters, instructing the model to treat submitted content as data, and keeping score calculation in backend code. Moderation is designed to run before analysis and fail closed if it cannot complete.

**Ready answer:**  
“We treat user-provided content as untrusted input because a video or caption might contain instructions aimed at the model. The documented design sanitizes and delimits that content, uses safety checks, validates the model output, and calculates scores in normal backend code. These measures reduce risk, but they cannot guarantee that every prompt-injection attempt will fail.”

## 8. Reliability and failure handling

AI can fail because of invalid credentials, model access, rate limits, timeouts, network problems, unsupported media, or malformed responses.

The project documentation describes readiness checks, structured response validation, a repair retry for invalid ratings, backoff for transient provider errors, explicit failed job states, stale-job recovery, and partial persona results that do not necessarily invalidate the full report.

The verification ledger also says that live Gemini and Supabase integrations were not executed in the original offline sandbox. Passing isolated tests with fake responses does not prove the live model integration works.

## 9. Ready viva questions and answers

**Q1. What does Gemini do in ViralForge?**  
“It generates content assessments and explanations. The backend validates the response and calculates the final scores.”

**Q2. What does the `google-genai` SDK do?**  
“It provides a software interface for calling Google's AI services. The SDK sends and receives model requests; our application defines how those responses are validated and used.”

**Q3. What is multimodal AI?**  
“It refers to AI that can process more than one type of information, such as visual and textual input. I would explain the exact media flow used by our configured model rather than claim every model has the same capability.”

**Q4. Why does backend code calculate the final score?**  
“Fixed formulas make the arithmetic reproducible. Gemini provides ratings; backend code validates them and calculates the final report scores.”

**Q5. What is structured output?**  
“It is a response constrained to an expected data shape. We still validate the response because a model can return missing or invalid values.”

**Q6. Are the persona reactions real feedback?**  
“No. They are AI-generated simulations based on predefined viewer profiles. They can help brainstorm but cannot replace real user research.”

**Q7. What happens if Gemini returns an invalid rating?**  
“The documented design validates the rating and attempts a repair retry. If the response remains invalid, the job can fail rather than treating the invalid value as trustworthy.”

**Q8. What is prompt injection?**  
“It is an attempt by untrusted content to influence the model's instructions. We reduce the risk by treating submitted content as data, sanitizing and delimiting it, and keeping critical score calculation in backend code.”

**Q9. Why use a background job?**  
“Video preparation and AI calls can take longer than a typical request. A job ID lets the API respond quickly while the worker processes the analysis.”

**Q10. Does a passing mocked test prove Gemini works?**  
“No. It proves the tested code behaves as expected against the fake response. A live integration test is needed to check real credentials, provider access, media upload, and model behavior.”

**Q11. How would you reduce AI latency?**  
“I would first measure where time is spent: upload, moderation, model processing, parsing, or database work. Then I would optimize the actual bottleneck and verify that the result quality remains acceptable.”

**Q12. How did you contribute if AI helped write the code?**  
“I would explain honestly which development tasks were AI-assisted and which parts I personally reviewed, changed, integrated, tested, or debugged. I would then demonstrate the real pipeline and explain its failure cases instead of claiming I manually wrote code I did not write.”

**Q13. Can the report guarantee virality?**  
“No. It is a rubric-based AI assessment. It does not control platform distribution and is not a validated guarantee of views or engagement.”

## 10. How to explain your contribution

Use this ready structure, replacing only the facts that are genuinely true:

“I was responsible for **[the AI-related task I actually worked on]**. The AI subsystem receives the submitted content and context, calls Gemini through the backend, and produces structured assessments. The backend validates those assessments and calculates the final scores. AI tools assisted with **[truthful scope]**. I personally **[actual review, integration, test, or debugging work]**, and I can demonstrate that by **[real evidence]**.”

Do not claim to have authored, tested, or integrated something if you did not. You can explain a module you have studied, but distinguish that from your original contribution.

## 11. Demonstration checklist

- Trace a job from queued to completed.
- Identify the actual Gemini gateway and its input/output.
- Explain the response validation.
- Explain one scoring formula.
- Show a relevant test if it passes in the current environment.
- Explain one model/provider failure.
- Explain why personas are simulations.
- State whether a demo is using a live model or a mock.
- Never show API keys or private content.

## 12. Quick revision

- **Inference:** model generating a response.
- **Prompt:** task instructions and context supplied to the model.
- **Multimodal:** handling multiple input types.
- **Structured output:** data in a defined shape.
- **Validation:** checking data against rules.
- **Prompt injection:** untrusted content trying to control model behavior.
- **Backoff:** waiting before retrying.
- **Persona simulation:** generated reactions from fictional viewer profiles.
- **Deterministic scoring:** fixed calculation from validated inputs.
- **Mock:** a controlled substitute used during testing.

**30-second explanation:**  
“ViralForge uses Gemini to assess short-form videos across seven dimensions, including hook strength, clarity, retention potential, and shareability. Gemini generates ratings and explanations, while backend code validates the output and calculates five final scores with fixed formulas. The system also creates AI-simulated reactions from ten viewer personas. The report helps creators consider improvements, but it does not guarantee virality or replace real audience testing.”

---

## Personal contribution reminder

This guide can help you explain the AI subsystem, but it cannot establish who personally wrote or tested each module. Be truthful about AI assistance, your actual contribution, and the evidence you can demonstrate.
