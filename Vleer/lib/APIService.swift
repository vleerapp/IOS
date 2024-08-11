import Foundation

class APIService {
    static func updateSearchWeight(query: String, selectedId: String) {
        guard let url = URL(string: "https://api.vleer.app/search/update-weight") else { return }
        
        let body: [String: String] = [
            "query": query,
            "selectedId": selectedId
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error updating search weight: \(error)")
            }
        }.resume()
    }
}
