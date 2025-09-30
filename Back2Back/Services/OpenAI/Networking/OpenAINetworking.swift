import Foundation
import OSLog

@MainActor
class OpenAINetworking {
    static let shared = OpenAINetworking()
    private init() {}

    func responses(request: ResponsesRequest, client: OpenAIClient) async throws -> ResponsesResponse {
        guard let apiKey = client.apiKey, !apiKey.isEmpty else {
            B2BLog.ai.error("API key missing when attempting responses API call")
            throw OpenAIError.apiKeyMissing
        }

        let urlString = OpenAIConstants.baseURL + OpenAIConstants.responsesEndpoint
        guard let url = URL(string: urlString) else {
            B2BLog.ai.error("Invalid URL: \(urlString)")
            throw OpenAIError.invalidURL
        }

        B2BLog.network.debug("🌐 API: POST \(urlString)")
        B2BLog.ai.debug("Model: \(request.model), Input length: \(request.input.count) characters")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let encoder = JSONEncoder()
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            B2BLog.ai.error("❌ Failed to encode request: \(error.localizedDescription)")
            throw OpenAIError.encodingError(error)
        }

        do {
            let startTime = Date()
            let (data, response) = try await client.session.data(for: urlRequest)
            let elapsedTime = Date().timeIntervalSince(startTime)

            B2BLog.network.debug("⏱️ OpenAI API Response Time: \(elapsedTime)")

            guard let httpResponse = response as? HTTPURLResponse else {
                B2BLog.ai.error("Invalid response type")
                throw OpenAIError.invalidResponse
            }

            B2BLog.ai.debug("HTTP Status Code: \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200:
                if let jsonString = String(data: data, encoding: .utf8) {
                    B2BLog.ai.debug("Raw API response: \(jsonString)")
                } else {
                    B2BLog.ai.error("Unable to convert response data to string")
                }

                do {
                    if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        B2BLog.ai.debug("Response keys: \(jsonObject.keys.sorted())")

                        if let output = jsonObject["output"] {
                            B2BLog.ai.debug("Output type: \(type(of: output))")
                            if let outputArray = output as? [[String: Any]] {
                                B2BLog.ai.debug("Output is array with \(outputArray.count) items")
                                if let firstItem = outputArray.first {
                                    B2BLog.ai.debug("First output item keys: \(firstItem.keys.sorted())")
                                }
                            } else if let outputString = output as? String {
                                B2BLog.ai.debug("Output is string: \(outputString)")
                            }
                        }

                        if let outputText = jsonObject["output_text"] {
                            B2BLog.ai.debug("output_text type: \(type(of: outputText))")
                        }
                    }
                } catch {
                    B2BLog.ai.error("Failed to parse as JSON object: \(error)")
                }

                do {
                    let decoder = JSONDecoder()
                    let responsesResponse = try decoder.decode(ResponsesResponse.self, from: data)

                    if let usage = responsesResponse.usage {
                        let reasoningTokens = usage.outputTokensDetails?.reasoningTokens ?? 0
                        B2BLog.ai.debug("Tokens used - Input: \(usage.inputTokens), Output: \(usage.outputTokens), Reasoning: \(reasoningTokens), Total: \(usage.totalTokens)")
                    }

                    B2BLog.ai.info("Responses API call successful")
                    return responsesResponse
                } catch let decodingError as DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        B2BLog.ai.error("❌ Decoding failed - Missing key: '\(key.stringValue)'")
                        B2BLog.ai.error("Context: \(context.debugDescription)")
                        B2BLog.ai.error("Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    case .valueNotFound(let type, let context):
                        B2BLog.ai.error("❌ Decoding failed - Missing value for type: \(type)")
                        B2BLog.ai.error("Context: \(context.debugDescription)")
                        B2BLog.ai.error("Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    case .typeMismatch(let type, let context):
                        B2BLog.ai.error("❌ Decoding failed - Type mismatch. Expected: \(type)")
                        B2BLog.ai.error("Context: \(context.debugDescription)")
                        B2BLog.ai.error("Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    case .dataCorrupted(let context):
                        B2BLog.ai.error("❌ Decoding failed - Data corrupted")
                        B2BLog.ai.error("Context: \(context.debugDescription)")
                        B2BLog.ai.error("Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    @unknown default:
                        B2BLog.ai.error("❌ Unknown decoding error: \(decodingError.localizedDescription)")
                    }
                    throw OpenAIError.decodingError(decodingError)
                } catch {
                    B2BLog.ai.error("❌ Failed to decode success response: \(error.localizedDescription)")
                    throw OpenAIError.decodingError(error)
                }

            case 401:
                B2BLog.ai.error("Unauthorized - Invalid API key")
                throw OpenAIError.unauthorized

            case 429:
                B2BLog.ai.warning("Rate limit exceeded")
                throw OpenAIError.rateLimitExceeded

            default:
                if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                    B2BLog.ai.error("API Error: \(errorResponse.error.message)")
                    throw OpenAIError.apiError(errorResponse.error.message)
                } else {
                    let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                    B2BLog.ai.error("HTTP Error \(httpResponse.statusCode): \(message)")
                    throw OpenAIError.httpError(statusCode: httpResponse.statusCode, message: message)
                }
            }
        } catch let error as OpenAIError {
            throw error
        } catch {
            B2BLog.ai.error("❌ Network error: \(error.localizedDescription)")
            throw OpenAIError.networkError(error)
        }
    }
}
