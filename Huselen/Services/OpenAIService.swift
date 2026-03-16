//
//  OpenAIService.swift
//  HuselenClient
//
//  Created for AI-powered meal analysis
//

import Foundation
import UIKit

// MARK: - OpenAI Service
class OpenAIService {
    static let shared = OpenAIService()
    
    private var apiKey: String {
        Config.MEALAI.apiKey
    }
    
    private let baseURL = Config.MEALAI.baseURL
    
    private init() {}
    
    // MARK: - Resize Image for API
    private func resizedImageForAPI(_ image: UIImage, maxDimension: CGFloat = 512) -> UIImage {
        let size = image.size
        guard max(size.width, size.height) > maxDimension else { return image }

        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    // MARK: - Analyze Meal Image
    func analyzeMealImage(_ image: UIImage, userContext: String? = nil) async throws -> MealAnalysisResult {
        guard !apiKey.isEmpty else {
            throw OpenAIError.missingAPIKey
        }

        // Resize + compress off main thread
        let base64Image: String = try await Task.detached(priority: .userInitiated) {
            let resized = await self.resizedImageForAPI(image)
            guard let imageData = resized.jpegData(compressionQuality: 0.5) else {
                throw OpenAIError.imageConversionFailed
            }
            return imageData.base64EncodedString()
        }.value
        
        // Build request
        let request = try buildRequest(base64Image: base64Image, userContext: userContext)
        
        // Make API call
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                throw OpenAIError.apiError(errorResponse.error.message)
            }
            throw OpenAIError.httpError(httpResponse.statusCode)
        }
        
        // Parse response
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        guard let content = openAIResponse.choices.first?.message.content else {
            throw OpenAIError.noContent
        }
        
        // Parse the JSON content from GPT response
        return try parseAnalysisResult(from: content)
    }
    
    // MARK: - Build Request
    private func buildRequest(base64Image: String, userContext: String? = nil) throws -> URLRequest {
        guard let url = URL(string: baseURL) else {
            throw OpenAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        // Build user context section if provided
        let userContextSection: String
        if let context = userContext, !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            userContextSection = """
            
            User's description of this meal: "\(context)"
            Use this information to better identify the foods and provide more accurate nutritional estimates.
            """
        } else {
            userContextSection = ""
        }
        
        let prompt = """
        Analyze this meal image and estimate the nutritional content.\(userContextSection)
        
        Respond ONLY with a valid JSON object in this exact format (no markdown, no code blocks):
        {
            "foods": [
                {
                    "name": "Tên món ăn bằng tiếng Việt",
                    "calories": 150,
                    "protein_g": 10.0,
                    "carbs_g": 20.0,
                    "fat_g": 5.0,
                    "serving_size": "1 phần",
                    "quantity": 1.0
                }
            ],
            "total_calories": 300,
            "total_protein_g": 20.0,
            "total_carbs_g": 40.0,
            "total_fat_g": 10.0,
            "meal_description": "Mô tả ngắn về bữa ăn bằng tiếng Việt",
            "health_note": "Gợi ý dinh dưỡng ngắn bằng tiếng Việt"
        }
        
        Important:
        - Use Vietnamese food names when applicable
        - Estimate calories and macros as accurately as possible based on portion sizes visible in the image
        - If you can't identify the food clearly, make your best estimate
        - All numeric values should be numbers, not strings
        """
        
        let requestBody: [String: Any] = [
            "model": Config.MEALAI.visionModel,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": prompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)",
                                "detail": "low"
                            ]
                        ]
                    ]
                ]
            ],
            "max_completion_tokens": Config.MEALAI.maxTokens
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        return request
    }
    
    // MARK: - Parse Analysis Result
    private func parseAnalysisResult(from content: String) throws -> MealAnalysisResult {
        // Clean up the content - remove markdown code blocks if present
        let cleanedContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanedContent.data(using: .utf8) else {
            throw OpenAIError.parseError("Failed to convert content to data")
        }
        
        do {
            let result = try JSONDecoder().decode(MealAnalysisResult.self, from: data)
            return result
        } catch {
            throw OpenAIError.parseError("Failed to parse JSON: \(error.localizedDescription)")
        }
    }
}

// MARK: - Meal Analysis Result
struct MealAnalysisResult: Codable {
    let foods: [AnalyzedFood]
    let totalCalories: Int
    let totalProteinG: Double
    let totalCarbsG: Double
    let totalFatG: Double
    let mealDescription: String?
    let healthNote: String?
    
    enum CodingKeys: String, CodingKey {
        case foods
        case totalCalories = "total_calories"
        case totalProteinG = "total_protein_g"
        case totalCarbsG = "total_carbs_g"
        case totalFatG = "total_fat_g"
        case mealDescription = "meal_description"
        case healthNote = "health_note"
    }
    
    // Convert to FoodItems for saving
    func toFoodItems() -> [MealLogFoodItem] {
        return foods.map { food in
            MealLogFoodItem(
                name: food.name,
                calories: food.calories,
                proteinG: food.proteinG,
                carbsG: food.carbsG,
                fatG: food.fatG,
                servingSize: food.servingSize,
                quantity: food.quantity ?? 1.0
            )
        }
    }
}

// MARK: - Analyzed Food
struct AnalyzedFood: Codable {
    let name: String
    let calories: Int
    let proteinG: Double?
    let carbsG: Double?
    let fatG: Double?
    let servingSize: String?
    let quantity: Double?
    
    enum CodingKeys: String, CodingKey {
        case name, calories, quantity
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case servingSize = "serving_size"
    }
}

// MARK: - OpenAI Response Models
struct OpenAIResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
    }
    
    struct Message: Codable {
        let content: String
    }
}

struct OpenAIErrorResponse: Codable {
    let error: OpenAIAPIError
    
    struct OpenAIAPIError: Codable {
        let message: String
        let type: String?
    }
}

// MARK: - OpenAI Errors
enum OpenAIError: LocalizedError {
    case missingAPIKey
    case imageConversionFailed
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case noContent
    case parseError(String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Chưa cấu hình OpenAI API Key"
        case .imageConversionFailed:
            return "Không thể xử lý hình ảnh"
        case .invalidURL:
            return "URL không hợp lệ"
        case .invalidResponse:
            return "Phản hồi không hợp lệ từ server"
        case .httpError(let code):
            return "Lỗi HTTP: \(code)"
        case .apiError(let message):
            return "Lỗi API: \(message)"
        case .noContent:
            return "Không có dữ liệu phản hồi"
        case .parseError(let message):
            return "Lỗi phân tích dữ liệu: \(message)"
        }
    }
}
