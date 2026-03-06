//
//  ClaudeAPIService.swift
//  SkyHigh - ControllerApp
//
//  Claude Messages API 클라이언트
//  POST https://api.anthropic.com/v1/messages

import Foundation
import RxSwift

// MARK: - Protocol

protocol ClaudeAPIServiceProtocol {
    func sendMessage(
        systemPrompt: String,
        messages: [ClaudeMessage]
    ) -> Observable<String>
}

// MARK: - Models

struct ClaudeMessage: Codable {
    let role: String   // "user" | "assistant"
    let content: String
}

private struct ClaudeRequest: Encodable {
    let model: String
    let max_tokens: Int
    let system: String
    let messages: [ClaudeMessage]
}

private struct ClaudeResponse: Decodable {
    let content: [ContentBlock]

    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }

    var text: String {
        content.compactMap { $0.type == "text" ? $0.text : nil }.joined()
    }
}

private struct ClaudeErrorResponse: Decodable {
    let error: APIError
    struct APIError: Decodable {
        let type: String
        let message: String
    }
}

// MARK: - Implementation

final class ClaudeAPIService: ClaudeAPIServiceProtocol {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func sendMessage(
        systemPrompt: String,
        messages: [ClaudeMessage]
    ) -> Observable<String> {
        Observable.create { [weak self] observer in
            guard let self else { return Disposables.create() }

            let request: URLRequest
            do {
                request = try self.buildRequest(
                    systemPrompt: systemPrompt,
                    messages: messages
                )
            } catch {
                observer.onError(AppError.aiAnalysisFailed("요청 생성 실패: \(error.localizedDescription)"))
                return Disposables.create()
            }

            let task = self.session.dataTask(with: request) { data, response, error in
                if let error {
                    observer.onError(AppError.aiAnalysisFailed(error.localizedDescription))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    observer.onError(AppError.aiAnalysisFailed("잘못된 응답 형식"))
                    return
                }

                guard let data else {
                    observer.onError(AppError.aiAnalysisFailed("응답 데이터 없음"))
                    return
                }

                guard httpResponse.statusCode == 200 else {
                    let errorMsg = (try? JSONDecoder().decode(ClaudeErrorResponse.self, from: data))
                        .map { "\($0.error.type): \($0.error.message)" }
                        ?? "HTTP \(httpResponse.statusCode)"
                    observer.onError(AppError.aiAnalysisFailed(errorMsg))
                    return
                }

                do {
                    let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
                    observer.onNext(decoded.text)
                    observer.onCompleted()
                } catch {
                    observer.onError(AppError.aiAnalysisFailed("응답 파싱 실패: \(error.localizedDescription)"))
                }
            }

            task.resume()
            return Disposables.create { task.cancel() }
        }
        .subscribe(on: ConcurrentDispatchQueueScheduler(qos: .userInitiated))
    }

    // MARK: - Private

    private func buildRequest(
        systemPrompt: String,
        messages: [ClaudeMessage]
    ) throws -> URLRequest {
        guard let url = URL(string: "\(BaseURL.claudeAPI)/v1/messages") else {
            throw AppError.aiAnalysisFailed("잘못된 API URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json",   forHTTPHeaderField: "Content-Type")
        request.setValue(BaseURL.claudeAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01",         forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 30

        let body = ClaudeRequest(
            model: BaseURL.claudeModel,
            max_tokens: 1024,
            system: systemPrompt,
            messages: messages
        )
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }
}
