 ViralForge Frontend
## Ready-to-speak explanations, file guide, technical concepts, and questions

This guide is written as a study document with ready answers. The explanations describe the documented ViralForge architecture. Where a specific source file or personal contribution cannot be established from public documentation alone, the guide says so rather than inventing it.

---

## 1. What is ViralForge?

**Ready answer:**  
“ViralForge is an AI-assisted application that helps creators evaluate short-form videos before publishing them. A user creates a project, uploads a video, selects a target platform and audience, and starts an analysis. The system produces a Viral Readiness Report with scores, strengths, weaknesses, recommendations, and AI-simulated viewer reactions. My area is the frontend, which lets users interact with the application and understand the analysis results.”

## 2. What does the frontend do?

**Simple explanation:** The frontend is the part the user sees and interacts with. It shows screens, collects input, sends requests to the backend, displays progress, and presents the final report.

**Technical explanation:** ViralForge's documented frontend uses Flutter Web and Dart. Riverpod is used for application state management, go_router for navigation, and Dio for HTTP communication with the FastAPI backend. Supabase Auth provides the documented email/password authentication flow.

**Ready answer:**  
“The frontend is responsible for the user experience. It collects project and video information, sends API requests, manages loading and error states, tracks analysis status, and displays the final report. It does not perform the entire AI analysis inside the browser; that work is coordinated by the backend.”

## 3. Frontend technologies

| Technology | Simple meaning | Ready explanation |
|---|---|---|
| Flutter Web | Framework for building browser interfaces | “We use Flutter's widget system to build the web interface.” |
| Dart | Programming language used by Flutter | “Dart defines the frontend behavior and UI components.” |
| Riverpod | State-management library | “It helps different parts of the interface access and react to changing application state.” |
| go_router | Navigation library | “It maps routes to screens and helps users move through the application.” |
| Dio | HTTP client | “It sends requests to the backend and receives responses.” |
| Supabase Auth | Authentication service | “It handles user sign-in and identity.” |
| FastAPI | Backend API framework | “It receives the frontend's requests and coordinates protected operations.” |

## 4. What the important files and folders do

The public repository identifies `frontend/`, `backend/`, `docs/`, `scripts/`, and `supabase/`. The exact names of all individual frontend source files should be checked in the current checkout; the explanations below describe the responsibilities of the relevant file types without inventing paths.

| File or area | What it does in simple English | Technical explanation |
|---|---|---|
| `frontend/` | Contains the browser application | Includes the Flutter/Dart UI, navigation, state, API communication, and report presentation. |
| App entry point | Starts the application | Initializes the root widget, app configuration, theme, and route system. |
| Route configuration | Chooses which screen to show | Defines route paths and navigation behavior through go_router. |
| Authentication screen/service | Lets the user sign in | Calls Supabase Auth and manages the result, session, loading state, and errors. |
| Project screens | Let users create and open projects | Send API requests and display project data returned by the backend. |
| Video selection/upload UI | Lets the user select and upload media | Handles file selection and sends upload data to the backend, commonly using multipart form data. |
| Analysis/status screen | Shows whether an analysis is queued or finished | Requests analysis creation and checks job status using the API. |
| Report widgets | Display scores and recommendations | Map the returned report data into readable UI elements. |
| API client/service | Centralizes server communication | Configures HTTP requests, headers, payloads, response parsing, and error handling. |
| Riverpod providers | Make changing data available to screens | Load or expose state such as projects, selected jobs, progress, and reports. |
| `frontend/config.json` | Holds generated public frontend configuration | The README describes it as generated and git-ignored; it must not contain backend service-role or Gemini secrets. |
| `scripts/run-frontend.ps1` | Starts the local frontend | The documented script regenerates frontend configuration and opens the app in Chrome at the configured local URL. |
| `docs/API.md` | Explains the backend API contract | Defines the routes, expected requests, responses, job states, and error format that the frontend consumes. |

**Ready answer if asked about a file:**  
“I explain a file by identifying its responsibility, its inputs, the functions or services it calls, the data it returns or displays, and its error behavior. I would trace that through the actual source rather than judging the file only by its name.”

## 5. How the frontend workflow works

1. The user signs in or registers.
2. The user creates or opens a project.
3. The user selects a video and supplies context such as platform and audience.
4. The frontend sends the relevant request to the backend.
5. The backend validates the request, stores the media, and creates an analysis job.
6. The frontend receives the job ID and shows a queued or processing state.
7. The frontend checks the job status.
8. Once the job completes, the frontend displays the Viral Readiness Report.

**Ready answer:**  
“When a user starts an analysis, the frontend sends a request to the backend. The backend returns a job identifier because analysis can take time. The frontend then checks the job status and displays the report when it is ready. This keeps the interface responsive instead of making the user wait for one long request.”

## 6. Technical concepts explained simply

### Widgets
A widget is a building block of a Flutter interface. Screens are composed from widgets, which can be reused to keep design and behavior consistent.

### State
State is information that changes while the app runs, such as selected project, upload progress, job status, error message, or report data. Riverpod helps organize and share this state.

### API
An API is a defined way for software components to communicate. In ViralForge, the frontend uses HTTP requests to communicate with the FastAPI backend.

### JSON
JSON is a structured data format used for objects such as project information, job status, and report results. File uploads may use multipart form data instead.

### Asynchronous request
An asynchronous request allows the app to continue responding while it waits for a network operation. A long-running analysis is handled as a background job rather than keeping the original request open.

### Authentication versus authorization
Authentication establishes who the user is. Authorization checks whether that user is allowed to access a particular project, video, or report. Hiding a screen does not replace backend authorization.

### Client-side validation
Client-side checks can warn users about invalid input before upload. They improve usability, but the backend must enforce security-sensitive rules because the client can be bypassed.

## 7. Ready viva questions and answers

**Q1. What is your module's role?**  
“My module is the frontend. It handles user interaction, input collection, navigation, communication with the backend, progress display, and presentation of the final report.”

**Q2. Why did the project use Flutter Web?**  
“Flutter provides a widget-based framework for building the web interface using Dart. It supports reusable components and a consistent UI structure. Browser-specific behavior and web deployment still need to be tested.”

**Q3. Why use Riverpod?**  
“Riverpod helps manage application state and makes data available to the parts of the UI that need it. I understand state management as keeping the displayed interface consistent with the current application data.”

**Q4. Why use Dio?**  
“Dio is an HTTP client used to communicate with the backend. It centralizes request handling and can support configuration such as headers and timeouts when those are implemented.”

**Q5. What does HTTP 202 mean?**  
“It means the backend accepted the request for processing. It does not mean the analysis has completed. The frontend must check the job status later.”

**Q6. Why are upload and analysis separate?**  
“Upload transfers the video and stores its metadata. Analysis is a separate, longer-running job that processes the stored video and can succeed or fail independently.”

**Q7. Is frontend validation enough to protect the server?**  
“No. Users can bypass the interface and call the API directly. The backend must repeat important checks for file size, format, duration, authentication, and resource ownership.”

**Q8. How would you debug a report that does not appear?**  
“I would check the browser's network request and error, verify the analysis ID and returned status, check the API response shape, and then inspect backend logs to find the earliest failing layer.”

**Q9. If the UI looks correct, does that prove the feature works?**  
“No. The screen can render correctly while the API, storage, authentication, or AI integration fails. The complete request path needs to be tested.”

**Q10. Did AI generate the frontend code?**  
“AI tools assisted with development to the extent they were used. What matters is that I can explain how the interface is structured, how its state changes, how API requests work, and how the result is displayed. I should clearly distinguish code generated by AI from changes, reviews, and tests I personally performed.”

**Q11. How did you create the frontend?**  
“The frontend was built around the user workflow: authentication, project management, video input, analysis status, and report display. Flutter widgets provide the UI, state management keeps the interface updated, routing connects the screens, and the API client communicates with the backend. I would explain the actual components and changes I worked on rather than claim I manually wrote every generated line.”

**Q12. What would you improve?**  
“I would first identify a real usability or reliability issue, reproduce it, and measure its effect. Then I would make a targeted change and verify it with a test or demonstration rather than proposing changes without evidence.”

**Q13. How can you prove you understand the frontend?**  
“I can trace a user action from the screen to the API request, explain the data and state transitions, show how the response becomes UI, and explain what happens on an error.”

## 8. How to answer questions about AI-assisted work

**Ready answer:**  
“We used AI assistance during development. I do not claim that every line was handwritten by me. My engineering responsibility is to understand the implementation, review how the parts fit together, verify behavior, and be able to explain the decisions and limitations. For my area, I can demonstrate the frontend workflow and explain how it communicates with the backend.”

Only say you personally reviewed, modified, tested, or debugged a feature if that is true. Understanding a module now is valuable, but it is different from claiming to have authored it manually.

## 9. Demonstration plan

- Sign in with a test account.
- Create or open a project.
- Show where a user selects a video and supplies platform/audience context.
- Start an analysis in a configured environment.
- Explain why the app shows a job status instead of waiting for all processing.
- Open a completed report and explain the displayed fields.
- Explain one error state or how a failed request is handled.
- Identify the actual route, state provider, API client, and screen in the checked-out source.
- Never reveal private keys, service-role credentials, or private user content.

## 10. Quick revision

- **Flutter:** UI framework.
- **Dart:** programming language.
- **Widget:** reusable UI building block.
- **Riverpod:** state management.
- **go_router:** navigation.
- **Dio:** HTTP client.
- **API contract:** agreed request/response format.
- **Polling:** checking a job's status repeatedly.
- **Authentication:** identity.
- **Authorization:** permissions.

**30-second project explanation:**  
“ViralForge's frontend is built with Flutter Web and Dart. It lets users sign in, create projects, upload short-form videos, select analysis context, track the job, and view the final report. It uses state management for UI updates and HTTP requests to communicate with the FastAPI backend. The frontend focuses on interaction and presentation, while the backend handles protected operations and the AI workflow.”

---

## Personal contribution reminder

Do not invent a personal work history. Be ready to state which parts you actually worked on, which parts were AI-assisted, what you reviewed or tested, and what you can demonstrate. The repository documentation alone cannot prove an individual's contribution.
