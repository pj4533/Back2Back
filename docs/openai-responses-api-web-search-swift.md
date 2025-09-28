# OpenAI Responses API + Web Search — **Streaming Events for Swift Apps**
_Last updated: 2025‑09‑28_

This developer guide is a **single, self‑contained** reference tailored for **Swift (iOS/macOS)** apps that use the **OpenAI Responses API** with the **Web Search** tool. It covers:

- Basics: endpoint, auth, request bodies (non‑streaming & streaming)
- **Web Search tool** configuration
- **Streaming events** you should handle — including the **Web Search–specific** events:
  - `response.web_search_call.in_progress`
  - `response.web_search_call.searching`
  - `response.web_search_call.completed`
- **Swift**-only code for making requests and parsing **SSE** events with **URLSession**
- UX guidance for user‑visible status (“Searching… / Found results… / Drafting answer…”)
- Full JSON **request** and **response** shapes (representative, based on current docs)

> Sources: official OpenAI docs (Responses streaming & Web Search) and SDK references.  
> - Streaming responses (guide): <https://platform.openai.com/docs/guides/streaming-responses>  
> - Responses API reference: <https://platform.openai.com/docs/api-reference/responses>  
> - Streaming events reference: <https://platform.openai.com/docs/api-reference/responses-streaming>  
> - Web Search tool: <https://platform.openai.com/docs/guides/tools-web-search>  
> - **Event pages:**  
>   - `response.web_search_call.in_progress` (streaming ref page)  
>   - `response.web_search_call.searching` (streaming ref page)  
>   - `response.web_search_call.completed` (streaming ref page)

---

## 0) Quick Start (curl)

**Non‑streaming (blocking):**
```bash
curl https://api.openai.com/v1/responses \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o-mini",
    "input": "Say hi in 5 words."
  }'
```

**Streaming (SSE) + Web Search enabled:**
```bash
curl https://api.openai.com/v1/responses \
  -N \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o",
    "tools": [{ "type": "web_search" }],
    "input": "Find one upbeat tech policy story from today and cite two sources.",
    "stream": true
  }'
```

---

## 1) Endpoint & Auth

**Endpoint**  
```
POST https://api.openai.com/v1/responses
```

**Headers**
```
Authorization: Bearer <OPENAI_API_KEY>
Content-Type: application/json
```

**Notes**
- `model` is required (e.g., `"gpt-4o"`, `"gpt-4o-mini"`).
- `input` can be a simple string or an array of rich parts (text, images, etc.).
- Add tools via `"tools": [{ "type": "web_search" }]`.
- Set `"stream": true` for **Server-Sent Events**.

Docs: API reference; streaming guide.

---

## 2) Request & Response — **Non‑Streaming**

### 2.1 Request (representative JSON)
```jsonc
{
  "model": "gpt-4o",
  "input": "Summarize the history of the Big Lebowski in two lines.",
  "tools": [
    { "type": "web_search" }
  ],
  "metadata": {
    "app": "MySwiftApp",
    "session_id": "abc-123"
  }
}
```

### 2.2 Response (representative JSON)
```jsonc
{
  "id": "resp_abc123",
  "object": "response",
  "model": "gpt-4o",
  "usage": { "input_tokens": 123, "output_tokens": 456, "total_tokens": 579 },
  "output": [
    {
      "type": "message",
      "role": "assistant",
      "content": [
        { "type": "output_text", "text": "Final answer text..." }
      ]
    }
  ],
  "status": "completed"
}
```
If the model used **Web Search**, you will also see **tool call** / **tool output** items in `output`. The Web Search guide explains the returned **web_search_call** item and the **message** that includes citations/annotations.

Docs: Responses API; Web Search.

---

## 3) Request & Response — **Streaming (SSE)**

### 3.1 Request (representative JSON)
```jsonc
{
  "model": "gpt-4o",
  "tools": [{ "type": "web_search" }],
  "input": "Find one positive tech policy story today with 2 sources and summarize in 3 bullets.",
  "stream": true
}
```

### 3.2 Streaming event flow (typical)
Server sends `data:` lines, each containing a JSON event object. Example high‑level sequence you may see:

```
data: { "type": "response.created", ... }
data: { "type": "response.web_search_call.in_progress", "web_search_call_id": "wsc_...", ... }
data: { "type": "response.web_search_call.searching",     "web_search_call_id": "wsc_...", ... }
data: { "type": "response.web_search_call.completed",     "web_search_call_id": "wsc_...", "results": { /* metadata/links */ } }
data: { "type": "response.output_text.delta", "delta": "First chunk..." }
data: { "type": "response.output_text.delta", "delta": " more text..." }
...
data: { "type": "response.completed", ... }
```

> Your Swift client should parse each line beginning with `data:`; ignore `[DONE]`. The **Web Search–specific** events above let you show **progress** in the UI.

Docs: Streaming responses / Streaming API reference; Web Search tool.

---

## 4) **Web Search** tool — Events & UX Mapping

OpenAI emits **Web Search–specific** streaming events while the search is underway:

- **`response.web_search_call.in_progress`** — the web search call is initiated (good moment to show “🔎 Starting web search…”).  
- **`response.web_search_call.searching`** — the search is actively running (show “🔎 Searching the web…”; you can animate a spinner).  
- **`response.web_search_call.completed`** — search results are ready (show “✅ Found results — drafting answer…”, optionally list sources).

References (event pages in the streaming API reference):  
- `response.web_search_call.in_progress` (Responses streaming reference)  
- `response.web_search_call.searching` (Responses streaming reference)  
- `response.web_search_call.completed` (Responses streaming reference)  
Also see: **Web Search** tool guide (how results & citations appear in the final message).

**Recommended UX mapping:**

| Event | Suggested status |
|---|---|
| `response.created` | “Thinking…” |
| `response.web_search_call.in_progress` | “🔎 Starting web search…” |
| `response.web_search_call.searching` | “🔎 Searching the web…” |
| `response.web_search_call.completed` | “✅ Results found — drafting answer…” (show sources) |
| `response.output_text.delta` | Append text to the transcript |
| `response.completed` | “Done.” |
| `response.error` | “⚠️ Error — tap for details” |

---

## 5) Swift — **Non‑Streaming** Request

```swift
import Foundation

struct ResponseObject: Decodable {
    let id: String
    let object: String
    let model: String
    let status: String?
    // Expand with fields you care about, e.g. usage/output...
}

func fetchResponseBlocking(prompt: String) async throws -> ResponseObject {
    var req = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
    req.httpMethod = "POST"
    req.addValue("Bearer \(ProcessInfo.processInfo.environment["OPENAI_API_KEY"]!)", forHTTPHeaderField: "Authorization")
    req.addValue("application/json", forHTTPHeaderField: "Content-Type")

    let body: [String: Any] = [
        "model": "gpt-4o-mini",
        "input": prompt,
        "tools": [["type": "web_search"]] // optional
    ]
    req.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, _) = try await URLSession.shared.data(for: req)
    return try JSONDecoder().decode(ResponseObject.self, from: data)
}
```

---

## 6) Swift — **Streaming** with URLSession (SSE)

Below is a pragmatic **line‑by‑line** SSE consumer that:
- Parses each `data:` line into a generic `StreamEvent` enum
- Handles **Web Search events** for UI status
- Appends **text deltas** to a buffer/closure for live rendering

```swift
import Foundation

// MARK: - Event Models

enum StreamEventType: String, Decodable {
    case responseCreated             = "response.created"
    case responseCompleted           = "response.completed"
    case responseError               = "response.error"
    case outputTextDelta             = "response.output_text.delta"

    // Web Search–specific:
    case webSearchInProgress         = "response.web_search_call.in_progress"
    case webSearchSearching          = "response.web_search_call.searching"
    case webSearchCompleted          = "response.web_search_call.completed"

    // Fallback for forward compatibility
    case other
}

struct StreamEvent: Decodable {
    let type: StreamEventType
    let delta: String?
    let web_search_call_id: String?
    let results: WebSearchResults?
    let error: APIError?
    
    enum CodingKeys: String, CodingKey {
        case type, delta, error
        case web_search_call_id
        case results
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawType = (try? c.decode(String.self, forKey: .type)) ?? ""
        self.type = StreamEventType(rawValue: rawType) ?? .other
        self.delta = try? c.decode(String.self, forKey: .delta)
        self.web_search_call_id = try? c.decode(String.self, forKey: .web_search_call_id)
        self.results = try? c.decode(WebSearchResults.self, forKey: .results)
        self.error = try? c.decode(APIError.self, forKey: .error)
    }
}

struct WebSearchResults: Decodable {
    // Shape may evolve; include what you need (e.g. sources/urls/snippets)
    let sources: [WebSource]?
}

struct WebSource: Decodable {
    let title: String?
    let url: String?
    let snippet: String?
}

struct APIError: Decodable {
    let message: String?
    let type: String?
}

// MARK: - Streamer

final class ResponsesStreamer {
    private let apiKey: String

    init(apiKey: String) { self.apiKey = apiKey }

    /// Starts a streaming response. Handlers are invoked on the calling actor.
    func startStream(
        prompt: String,
        showStatus: @escaping (String) -> Void,
        appendText: @escaping (String) -> Void,
        showSources: @escaping ([WebSource]) -> Void
    ) async throws {
        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        req.httpMethod = "POST"
        req.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4o",
            "tools": [["type": "web_search"]],
            "input": prompt,
            "stream": true
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, _) = try await URLSession.shared.bytes(for: req)

        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8) else { continue }

            // Decode as StreamEvent (tolerant to unknown fields)
            let evt: StreamEvent
            do {
                evt = try JSONDecoder().decode(StreamEvent.self, from: data)
            } catch {
                // Ignore unknown/diagnostic lines
                continue
            }

            switch evt.type {
            case .responseCreated:
                showStatus("Thinking…")
            case .webSearchInProgress:
                showStatus("🔎 Starting web search…")
            case .webSearchSearching:
                showStatus("🔎 Searching the web…")
            case .webSearchCompleted:
                showStatus("✅ Results found — drafting answer…")
                if let sources = evt.results?.sources, !sources.isEmpty {
                    showSources(sources)
                }
            case .outputTextDelta:
                if let d = evt.delta { appendText(d) }
            case .responseCompleted:
                showStatus("Done.")
            case .responseError:
                showStatus("⚠️ Error")
                if let errorMsg = evt.error?.message { appendText("\n[error] \(errorMsg)") }
            case .other:
                // Handle future event types as needed
                break
            }
        }
    }
}
```

**Usage in SwiftUI (example):**
```swift
@MainActor
final class ChatVM: ObservableObject {
    @Published var status: String = ""
    @Published var transcript: String = ""
    @Published var sources: [WebSource] = []

    private lazy var streamer = ResponsesStreamer(apiKey: ProcessInfo.processInfo.environment["OPENAI_API_KEY"]!)

    func ask(_ prompt: String) {
        Task {
            do {
                try await streamer.startStream(
                    prompt: prompt,
                    showStatus: { [weak self] s in self?.status = s },
                    appendText: { [weak self] t in self?.transcript += t },
                    showSources: { [weak self] src in self?.sources = src }
                )
            } catch {
                self.status = "⚠️ Error"
            }
        }
    }
}
```

---

## 7) JSON: **Streaming event objects** (representative)

Each SSE `data:` line is a single JSON object. Key examples with Web Search:

### 7.1 Web Search begins
```jsonc
{
  "type": "response.web_search_call.in_progress",
  "web_search_call_id": "wsc_789",
  "response_id": "resp_abc123",
  "timestamp": 1738112345
}
```

### 7.2 Web Search searching
```jsonc
{
  "type": "response.web_search_call.searching",
  "web_search_call_id": "wsc_789",
  "progress": { "phase": "fetching", "sources_consulted": 3 }
}
```

### 7.3 Web Search completed
```jsonc
{
  "type": "response.web_search_call.completed",
  "web_search_call_id": "wsc_789",
  "results": {
    "sources": [
      { "title": "Official Policy Brief", "url": "https://example.gov/policy", "snippet": "..." },
      { "title": "Tech News", "url": "https://news.example/...", "snippet": "..." }
    ]
  }
}
```

### 7.4 Text delta chunks
```jsonc
{
  "type": "response.output_text.delta",
  "delta": "This is the first chunk ",
  "content_index": 0,
  "sequence_number": 1
}
```

### 7.5 Completed / Error
```jsonc
{ "type": "response.completed", "response_id": "resp_abc123" }
```
```jsonc
{ "type": "response.error", "error": { "message": "Rate limit", "type": "rate_limit" } }
```

> Field names can evolve; the **event `type` strings above are canonical** for the Web Search progress states. Always code your Swift decoder to be **forward‑compatible** (ignore unknown fields).

Docs: Responses streaming API; Web Search tool guide; event pages for the three Web Search events.

---

## 8) Tips for Robust Swift UX

- **Debounce status** text to avoid flicker when `in_progress` quickly becomes `searching`.
- **Show sources** as soon as you receive them in `web_search_call.completed` (even before all text deltas are done).
- **Accumulate text** from `response.output_text.delta` for a responsive feel.
- If the stream **drops** before `response.completed`, show “Reconnecting…” and allow a **retry** (optionally re‑issue the same prompt). Consider Background mode + webhooks (see docs) for long tasks.
- Log `response.error` details and present a user‑friendly toast/snackbar.

---

## 9) Full **cURL** + **Swift** Examples

### 9.1 curl — non‑streaming
```bash
curl https://api.openai.com/v1/responses \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o-mini",
    "input": "Write a one-line haiku about fog."
  }'
```

### 9.2 curl — streaming + Web Search
```bash
curl https://api.openai.com/v1/responses \
  -N \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o",
    "tools": [{ "type": "web_search" }],
    "input": "Find one positive tech policy story today and cite 2 sources.",
    "stream": true
  }'
```

### 9.3 Swift — helpers recap
- Use `URLSession.shared.bytes(for:)` to get an **async sequence** of lines.
- Each line starting with `data:` is a **JSON event** — decode as `StreamEvent`.
- Switch on `event.type` to show status & append deltas (see §6).

---

## 10) Appendix — FAQ

**Q: Do I need the Agents SDK to get Web Search progress?**  
**A:** No. The **Responses API** itself emits the Web Search events documented above. The Agents SDK adds ergonomics, but isn’t required for Swift clients.

**Q: Where do the citations/links appear?**  
**A:** In the final assistant **message** (part of `output`) and/or in the **web_search_call.completed** event payload (`results.sources`). Render them as the search concludes, then keep streaming the answer.

**Q: Can I show the model’s exact search query?**  
**A:** Some models and settings surface this in Web Search outputs or reasoning summaries; availability can vary. Prefer showing **sources** and your own “Searching…”/“Found results…” states.

---

### References (Official)
- Streaming responses (guide): <https://platform.openai.com/docs/guides/streaming-responses>  
- Responses API reference: <https://platform.openai.com/docs/api-reference/responses>  
- Streaming API (events): <https://platform.openai.com/docs/api-reference/responses-streaming>  
- Web Search tool guide: <https://platform.openai.com/docs/guides/tools-web-search>  
- Event pages: `response.web_search_call.in_progress`, `response.web_search_call.searching`, `response.web_search_call.completed`

**End of file.**
